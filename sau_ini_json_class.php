<?php

# depends on https://github.com/stokkeland/nix_collection/blob/main/sau_ini_manager.php
# which in turn is using same lock file setup as bash script
#   https://github.com/stokkeland/nix_collection/blob/main/sau_ini

require_once 'sau_ini_manager.php'; // Assumes the sau_ini_manager class is in this file

/**
 * sau_ini_json - JSON-oriented INI file handler using sau_ini_manager
 * 
 * Description:
 *   This class provides a JSON-like interface for reading and writing INI files
 *   as single-level associative arrays. It uses the sau_ini_manager class for
 *   safe, atomic operations with file locking.
 *
 * Features:
 *   - Read individual keys, multiple keys, or entire sections as JSON
 *   - Write associative arrays to INI sections
 *   - Flexible key selection (string, array, or all keys)
 *   - Uses sau_ini_manager for safe concurrent access
 *   - Returns JSON strings for easy API integration
 *   - Handles type conversion between INI strings and PHP values
 *
 * Usage Examples:
 *   // Default behavior - no type conversion (all values as strings)
 *   $json_ini = new sau_ini_json();
 *   
 *   // Enable type conversion (strings converted to int/float/bool when appropriate)
 *   $json_ini = new sau_ini_json(true);
 *   
 *   // Read single key as JSON
 *   $host_json = $json_ini->ini_read('config.ini', 'database', 'host');
 *   // Returns: '{"host":"localhost"}' (always string with default)
 *   
 *   // With conversion enabled and numeric value:
 *   // Returns: '{"port":3306}' (as integer, not string)
 *   
 *   // Write associative array to section
 *   $json_ini->ini_write('config.ini', 'database', [
 *       'host' => 'localhost',
 *       'port' => 3306,
 *       'name' => 'mydb'
 *   ]);
 *
 * Author: Compatible with sau_ini_manager and bash ini_manager script
 * Version: 1.0
 */
class sau_ini_json
{
    private $iniManager;
    private $valueConvert;

    /**
     * Constructor
     * 
     * @param bool $value_convert Whether to convert values to appropriate types (default: false)
     *                           false = store/return all values as strings
     *                           true = convert strings to int/float/bool when appropriate
     */
    public function __construct($value_convert = false)
    {
        $this->valueConvert = $value_convert;
        // sau_ini_manager will be instantiated per operation to avoid file handle conflicts
    }

    /**
     * Read data from INI file and return as JSON
     * 
     * @param string $file Path to INI file
     * @param string $section Section name
     * @param mixed $keys Key selection:
     *                    - string: return single key
     *                    - array: return specified keys
     *                    - empty/null: return all keys in section
     * @return string JSON representation of the data
     * @throws Exception On file errors or invalid parameters
     */
    public function ini_read($file, $section, $keys = [])
    {
        if (empty($file) || empty($section)) {
            throw new Exception("File path and section name cannot be empty");
        }

        $iniManager = new sau_ini_manager($file);
        
        try {
            // Handle different key selection types
            if (is_string($keys) && !empty($keys)) {
                // Single key requested
                $value = $iniManager->read($section, $keys);
                if ($value === null) {
                    return json_encode([]); // Key not found
                }
                return json_encode([$keys => $this->convertValue($value)]);
                
            } elseif (is_array($keys) && !empty($keys)) {
                // Multiple specific keys requested
                $result = [];
                foreach ($keys as $key) {
                    $value = $iniManager->read($section, $key);
                    if ($value !== null) {
                        $result[$key] = $this->convertValue($value);
                    }
                }
                return json_encode($result);
                
            } else {
                // All keys in section requested (default behavior)
                $sectionData = $iniManager->read($section);
                if ($sectionData === null) {
                    return json_encode([]); // Section not found
                }
                
                // Convert all values
                $result = [];
                foreach ($sectionData as $key => $value) {
                    $result[$key] = $this->convertValue($value);
                }
                return json_encode($result);
            }
            
        } catch (Exception $e) {
            throw new Exception("Failed to read from INI file: " . $e->getMessage());
        }
    }

    /**
     * Write associative array data to INI file section
     * 
     * @param string $file Path to INI file
     * @param string $section Section name
     * @param array $keyvalue Associative array of key-value pairs to write
     * @throws Exception On file errors or invalid parameters
     */
    public function ini_write($file, $section, $keyvalue = [])
    {
        if (empty($file) || empty($section)) {
            throw new Exception("File path and section name cannot be empty");
        }

        if (!is_array($keyvalue)) {
            throw new Exception("Key-value data must be an associative array");
        }

        if (empty($keyvalue)) {
            return; // Nothing to write
        }

        $iniManager = new sau_ini_manager($file);
        
        try {
            foreach ($keyvalue as $key => $value) {
                if (empty($key)) {
                    throw new Exception("Key cannot be empty");
                }
                
                // Validate that value is a simple scalar type
                if (!is_scalar($value) && $value !== null) {
                    $type = gettype($value);
                    throw new Exception("JSON data must be single level array only. Key '$key' contains invalid type: $type");
                }
                
                // Convert value to string representation suitable for INI
                $iniValue = $this->convertToIniValue($value);
                $iniManager->write($section, $key, $iniValue);
            }
            
        } catch (Exception $e) {
            throw new Exception("Failed to write to INI file: " . $e->getMessage());
        }
    }

    /**
     * Read data from INI file and return as PHP array (not JSON string)
     * 
     * @param string $file Path to INI file
     * @param string $section Section name
     * @param mixed $keys Key selection (same as ini_read)
     * @return array PHP associative array
     * @throws Exception On file errors or invalid parameters
     */
    public function ini_read_array($file, $section, $keys = [])
    {
        $json = $this->ini_read($file, $section, $keys);
        return json_decode($json, true);
    }

    /**
     * Convert INI string value to appropriate PHP type
     * 
     * @param string $value Raw value from INI file
     * @return mixed Converted value (string, int, float, bool, or null) or string if conversion disabled
     */
    private function convertValue($value)
    {
        if ($value === null || $value === '') {
            return null;
        }

        // If value conversion is disabled, return as-is (string)
        if (!$this->valueConvert) {
            return $value;
        }

        // Convert string representations to appropriate types
        $lower = strtolower(trim($value));
        
        // Boolean values
        if (in_array($lower, ['true', '1', 'on', 'yes'])) {
            return true;
        }
        if (in_array($lower, ['false', '0', 'off', 'no', ''])) {
            return false;
        }
        
        // Numeric values
        if (is_numeric($value)) {
            // Check if it's an integer
            if ((string)(int)$value === (string)$value) {
                return (int)$value;
            }
            // Otherwise it's a float
            return (float)$value;
        }
        
        // Return as string (default)
        return $value;
    }

    /**
     * Convert PHP value to INI-appropriate string representation
     * 
     * @param mixed $value PHP value to convert
     * @return string String representation for INI file
     */
    private function convertToIniValue($value)
    {
        if ($value === null) {
            return '';
        }
        
        // If value conversion is disabled, convert everything to string as-is
        if (!$this->valueConvert) {
            return (string)$value;
        }
        
        if (is_bool($value)) {
            return $value ? '1' : '0';
        }
        
        if (is_numeric($value)) {
            return (string)$value;
        }
        
        // For strings, return as-is (sau_ini_manager will handle escaping if needed)
        return (string)$value;
    }

    /**
     * Check if a section exists in the INI file
     * 
     * @param string $file Path to INI file
     * @param string $section Section name
     * @return bool True if section exists
     * @throws Exception On file errors
     */
    public function section_exists($file, $section)
    {
        if (empty($file) || empty($section)) {
            throw new Exception("File path and section name cannot be empty");
        }

        $iniManager = new sau_ini_manager($file);
        
        try {
            $sections = $iniManager->getSections();
            return in_array($section, $sections);
            
        } catch (Exception $e) {
            throw new Exception("Failed to check section existence: " . $e->getMessage());
        }
    }

    /**
     * Get all sections in the INI file as JSON array
     * 
     * @param string $file Path to INI file
     * @return string JSON array of section names
     * @throws Exception On file errors
     */
    public function get_sections($file)
    {
        if (empty($file)) {
            throw new Exception("File path cannot be empty");
        }

        $iniManager = new sau_ini_manager($file);
        
        try {
            $sections = $iniManager->getSections();
            return json_encode($sections);
            
        } catch (Exception $e) {
            throw new Exception("Failed to get sections: " . $e->getMessage());
        }
    }

    /**
     * Get all keys in a section as JSON array
     * 
     * @param string $file Path to INI file
     * @param string $section Section name
     * @return string JSON array of key names
     * @throws Exception On file errors
     */
    public function get_keys($file, $section)
    {
        if (empty($file) || empty($section)) {
            throw new Exception("File path and section name cannot be empty");
        }

        $iniManager = new sau_ini_manager($file);
        
        try {
            $keys = $iniManager->getKeys($section);
            return json_encode($keys);
            
        } catch (Exception $e) {
            throw new Exception("Failed to get keys: " . $e->getMessage());
        }
    }

    /**
     * Delete a key from INI file
     * 
     * @param string $file Path to INI file
     * @param string $section Section name
     * @param string $key Key name
     * @return bool True if key was deleted, false if not found
     * @throws Exception On file errors
     */
    public function ini_delete($file, $section, $key)
    {
        if (empty($file) || empty($section) || empty($key)) {
            throw new Exception("File path, section name, and key cannot be empty");
        }

        $iniManager = new sau_ini_manager($file);
        
        try {
            return $iniManager->delete($section, $key);
            
        } catch (Exception $e) {
            throw new Exception("Failed to delete key: " . $e->getMessage());
        }
    }
}

// Example usage:
/*
try {
    // Default behavior - no type conversion
    $json_ini = new sau_ini_json();
    
    // Or enable type conversion
    // $json_ini = new sau_ini_json(true);
    
    // Write some data
    $json_ini->ini_write('config.ini', 'database', [
        'host' => 'localhost',
        'port' => 3306,
        'name' => 'myapp',
        'ssl' => true,
        'timeout' => 30.5
    ]);
    
    // With $value_convert = false (default):
    // All values returned as strings: {"port":"3306","ssl":"1","timeout":"30.5"}
    
    // With $value_convert = true:
    // Values converted to appropriate types: {"port":3306,"ssl":true,"timeout":30.5}
    
    // Read single key
    $host = $json_ini->ini_read('config.ini', 'database', 'host');
    echo "Host (JSON): $host\n"; // {"host":"localhost"}
    
    // Read multiple keys
    $connection = $json_ini->ini_read('config.ini', 'database', ['host', 'port', 'name']);
    echo "Connection (JSON): $connection\n"; // {"host":"localhost","port":3306,"name":"myapp"}
    
    // Read entire section
    $all_db = $json_ini->ini_read('config.ini', 'database');
    echo "All database config (JSON): $all_db\n";
    
    // Read as PHP array instead of JSON
    $db_array = $json_ini->ini_read_array('config.ini', 'database');
    var_dump($db_array);
    
    // Get sections
    $sections = $json_ini->get_sections('config.ini');
    echo "Sections: $sections\n";
    
    // Check if section exists
    $exists = $json_ini->section_exists('config.ini', 'database');
    echo "Database section exists: " . ($exists ? 'yes' : 'no') . "\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
*/
