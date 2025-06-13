<?php

/**
 * Sau INI Manager - A robust PHP class for INI file manipulation with file locking
 * 
 * Description:
 *   This class provides safe, atomic operations for reading, writing, and deleting
 *   keys in INI configuration files. It uses the same file locking mechanism as
 *   the companion bash script to prevent concurrent modifications.
 *
 * There is a bash script available that does the same thing, use the same lock files
 *   https://github.com/stokkeland/nix_collection/blob/main/sau_ini
 *
 * Features:
 *   - Read individual keys, sections, or entire INI files
 *   - Write/update key-value pairs (creates sections if needed)
 *   - Delete individual keys or entire sections
 *   - Atomic operations with file locking compatible with bash script
 *   - Preserves file permissions and ownership
 *   - Handles stale locks (removes locks older than 2 minutes)
 *   - Uses PHP's native parse_ini_file() and parse_ini_string() functions
 *
 * Usage Examples:
 *   $ini = new sau_ini_manager('config.ini');
 *   
 *   // Read a value
 *   $host = $ini->read('database', 'host');
 *   
 *   // Write a value
 *   $ini->write('database', 'host', 'localhost');
 *   
 *   // Delete a key
 *   $ini->delete('database', 'password');
 *   
 *   // Get all sections
 *   $sections = $ini->getSections();
 *   
 *   // Get all keys in a section
 *   $keys = $ini->getKeys('database');
 *   
 *   // Get entire INI as array
 *   $config = $ini->getAll();
 *
 * Author: Compatible with bash ini_manager script
 * Version: 1.0
 */
class sau_ini_manager
{
    private $iniFile;
    private $lockFile;
    private $lockHandle;
    private $lockTimeout = 120; // 2 minutes in seconds
    private $lockRetries = 10;
    private $lockWait = 100000; // 0.1 seconds in microseconds

    /**
     * Constructor
     * 
     * @param string $iniFile Path to the INI file
     * @throws Exception If file path is invalid
     */
    public function __construct($iniFile)
    {
        if (empty($iniFile)) {
            throw new Exception("INI file path cannot be empty");
        }
        
        $this->iniFile = $iniFile;
        $this->lockFile = $this->getLockFilePath($iniFile);
    }

    /**
     * Destructor - ensures lock is released
     */
    public function __destruct()
    {
        $this->releaseLock();
    }

    /**
     * Generate lock file path using same logic as bash script
     * 
     * @param string $iniFile Path to INI file
     * @return string Lock file path
     */
    private function getLockFilePath($iniFile)
    {
        $iniDir = dirname($iniFile);
        $basename = basename($iniFile);
        
        // Try to use same directory as INI file
        if (is_writable($iniDir)) {
            return $iniDir . '/.' . $basename . '.lock';
        } else {
            // Use /tmp with path hash (same as bash script)
            $absPath = realpath($iniFile) ?: $iniFile;
            $pathHash = md5($absPath);
            return '/tmp/ini_manager.' . $pathHash . '.lock';
        }
    }

    /**
     * Acquire file lock with stale lock handling
     * 
     * @throws Exception If lock cannot be acquired
     */
    private function acquireLock()
    {
        // Check for stale lock before creating/opening
        if (file_exists($this->lockFile)) {
            $lockAge = time() - filemtime($this->lockFile);
            if ($lockAge > $this->lockTimeout) {
                error_log("[INI Manager] Removing stale lock file ({$lockAge}s old, timeout: {$this->lockTimeout}s)");
                unlink($this->lockFile);
            }
        }

        // Create lock file if it doesn't exist
        if (!file_exists($this->lockFile)) {
            touch($this->lockFile);
            chmod($this->lockFile, 0600);
        }

        // Open lock file for exclusive access
        $this->lockHandle = fopen($this->lockFile, 'w');
        if (!$this->lockHandle) {
            throw new Exception("Cannot open lock file: {$this->lockFile}");
        }

        // Try to acquire exclusive lock with retries
        for ($i = 1; $i <= $this->lockRetries; $i++) {
            if (flock($this->lockHandle, LOCK_EX | LOCK_NB)) {
                return; // Lock acquired successfully
            }
            
            if ($i === $this->lockRetries) {
                fclose($this->lockHandle);
                $this->lockHandle = null;
                throw new Exception("Could not acquire lock after {$this->lockRetries} attempts");
            }
            
            usleep($this->lockWait);
        }
    }

    /**
     * Release file lock and cleanup
     */
    private function releaseLock()
    {
        if ($this->lockHandle) {
            flock($this->lockHandle, LOCK_UN);
            fclose($this->lockHandle);
            $this->lockHandle = null;
            
            // Clean up lock file
            if (file_exists($this->lockFile)) {
                unlink($this->lockFile);
            }
        }
    }

    /**
     * Validate INI file format
     * 
     * @throws Exception If file is missing, unreadable, or invalid format
     */
    private function validateIni()
    {
        if (!file_exists($this->iniFile) || !is_readable($this->iniFile)) {
            throw new Exception("File missing or unreadable: {$this->iniFile}");
        }

        $content = file_get_contents($this->iniFile);
        if ($content === false) {
            throw new Exception("Cannot read file: {$this->iniFile}");
        }

        // Basic validation - must have at least one section and one key=value
        if (!preg_match('/^\[.*\]/m', $content) || !preg_match('/^[^#;].*=.*$/m', $content)) {
            throw new Exception("Invalid INI format: {$this->iniFile}");
        }
    }

    /**
     * Read a value from the INI file
     * 
     * @param string $section Section name
     * @param string $key Key name (optional - if null, returns entire section)
     * @return mixed Value, section array, or null if not found
     * @throws Exception On file errors
     */
    public function read($section, $key = null)
    {
        $this->acquireLock();
        
        try {
            $this->validateIni();
            
            $data = parse_ini_file($this->iniFile, true, INI_SCANNER_RAW);
            if ($data === false) {
                throw new Exception("Failed to parse INI file: {$this->iniFile}");
            }

            if (!isset($data[$section])) {
                return null; // Section not found
            }

            if ($key === null) {
                return $data[$section]; // Return entire section
            }

            if (!isset($data[$section][$key])) {
                return null; // Key not found
            }

            // Trim whitespace from value (same as bash script)
            return trim($data[$section][$key]);
            
        } finally {
            $this->releaseLock();
        }
    }

    /**
     * Write a key-value pair to the INI file
     * 
     * @param string $section Section name
     * @param string $key Key name
     * @param mixed $value Value to write
     * @throws Exception On file errors or invalid parameters
     */
    public function write($section, $key, $value)
    {
        if (empty($section) || empty($key)) {
            throw new Exception("Section and key cannot be empty");
        }

        $this->acquireLock();
        
        try {
            // Read existing data or create new structure
            $data = [];
            if (file_exists($this->iniFile)) {
                $this->validateIni();
                $data = parse_ini_file($this->iniFile, true, INI_SCANNER_RAW);
                if ($data === false) {
                    $data = [];
                }
            }

            // Update the data
            if (!isset($data[$section])) {
                $data[$section] = [];
            }
            $data[$section][$key] = $value;

            // Write to temporary file with preserved permissions
            $this->writeIniFile($data);
            
        } finally {
            $this->releaseLock();
        }
    }

    /**
     * Delete a key from the INI file
     * 
     * @param string $section Section name
     * @param string $key Key name
     * @return bool True if key was deleted, false if not found
     * @throws Exception On file errors
     */
    public function delete($section, $key)
    {
        if (empty($section) || empty($key)) {
            throw new Exception("Section and key cannot be empty");
        }

        $this->acquireLock();
        
        try {
            $this->validateIni();
            
            $data = parse_ini_file($this->iniFile, true, INI_SCANNER_RAW);
            if ($data === false) {
                throw new Exception("Failed to parse INI file: {$this->iniFile}");
            }

            if (!isset($data[$section]) || !isset($data[$section][$key])) {
                return false; // Key not found
            }

            unset($data[$section][$key]);
            
            // Remove section if empty
            if (empty($data[$section])) {
                unset($data[$section]);
            }

            $this->writeIniFile($data);
            return true;
            
        } finally {
            $this->releaseLock();
        }
    }

    /**
     * Get all sections in the INI file
     * 
     * @return array Array of section names
     * @throws Exception On file errors
     */
    public function getSections()
    {
        $this->acquireLock();
        
        try {
            $this->validateIni();
            
            $data = parse_ini_file($this->iniFile, true, INI_SCANNER_RAW);
            if ($data === false) {
                throw new Exception("Failed to parse INI file: {$this->iniFile}");
            }

            return array_keys($data);
            
        } finally {
            $this->releaseLock();
        }
    }

    /**
     * Get all keys in a section
     * 
     * @param string $section Section name
     * @return array Array of key names, or empty array if section not found
     * @throws Exception On file errors
     */
    public function getKeys($section)
    {
        $this->acquireLock();
        
        try {
            $this->validateIni();
            
            $data = parse_ini_file($this->iniFile, true, INI_SCANNER_RAW);
            if ($data === false) {
                throw new Exception("Failed to parse INI file: {$this->iniFile}");
            }

            if (!isset($data[$section])) {
                return [];
            }

            return array_keys($data[$section]);
            
        } finally {
            $this->releaseLock();
        }
    }

    /**
     * Get entire INI file as associative array
     * 
     * @return array Complete INI data structure
     * @throws Exception On file errors
     */
    public function getAll()
    {
        $this->acquireLock();
        
        try {
            $this->validateIni();
            
            $data = parse_ini_file($this->iniFile, true, INI_SCANNER_RAW);
            if ($data === false) {
                throw new Exception("Failed to parse INI file: {$this->iniFile}");
            }

            return $data;
            
        } finally {
            $this->releaseLock();
        }
    }

    /**
     * Write INI data to file while preserving permissions
     * 
     * @param array $data INI data structure
     * @throws Exception On write errors
     */
    private function writeIniFile($data)
    {
        // Get original file permissions
        $originalPerms = null;
        $originalOwner = null;
        $originalGroup = null;
        
        if (file_exists($this->iniFile)) {
            $stat = stat($this->iniFile);
            $originalPerms = $stat['mode'] & 0777;
            $originalOwner = $stat['uid'];
            $originalGroup = $stat['gid'];
        }

        // Create temporary file
        $tempFile = tempnam(dirname($this->iniFile), 'ini_temp_');
        if (!$tempFile) {
            throw new Exception("Cannot create temporary file");
        }

        try {
            // Build INI content
            $content = $this->buildIniContent($data);
            
            // Write to temporary file
            if (file_put_contents($tempFile, $content) === false) {
                throw new Exception("Failed to write temporary file");
            }

            // Set permissions before moving
            if ($originalPerms !== null) {
                chmod($tempFile, $originalPerms);
            }
            if ($originalOwner !== null && $originalGroup !== null) {
                @chown($tempFile, $originalOwner);
                @chgrp($tempFile, $originalGroup);
            }

            // Atomic move
            if (!rename($tempFile, $this->iniFile)) {
                throw new Exception("Failed to replace INI file");
            }
            
        } catch (Exception $e) {
            // Clean up temp file on error
            if (file_exists($tempFile)) {
                unlink($tempFile);
            }
            throw $e;
        }
    }

    /**
     * Build INI file content from data array
     * 
     * @param array $data INI data structure
     * @return string INI file content
     */
    private function buildIniContent($data)
    {
        $content = '';
        
        foreach ($data as $section => $keys) {
            $content .= "[$section]\n";
            
            if (is_array($keys)) {
                foreach ($keys as $key => $value) {
                    // Escape special characters in values
                    if (is_string($value) && (strpos($value, '"') !== false || strpos($value, ';') !== false || strpos($value, '#') !== false)) {
                        $value = '"' . str_replace('"', '""', $value) . '"';
                    }
                    $content .= "$key=$value\n";
                }
            }
            
            $content .= "\n";
        }
        
        return $content;
    }

    /**
     * Set lock timeout in seconds
     * 
     * @param int $seconds Timeout in seconds
     */
    public function setLockTimeout($seconds)
    {
        $this->lockTimeout = (int)$seconds;
    }

    /**
     * Get current lock timeout
     * 
     * @return int Timeout in seconds
     */
    public function getLockTimeout()
    {
        return $this->lockTimeout;
    }
}

// Example usage:
/*
try {
    $ini = new sau_ini_manager('config.ini');
    
    // Read a value
    $host = $ini->read('database', 'host');
    echo "Database host: " . ($host ?? 'not found') . "\n";
    
    // Write a value
    $ini->write('database', 'host', 'localhost');
    $ini->write('database', 'port', 3306);
    
    // List sections
    $sections = $ini->getSections();
    echo "Sections: " . implode(', ', $sections) . "\n";
    
    // List keys in a section
    $keys = $ini->getKeys('database');
    echo "Database keys: " . implode(', ', $keys) . "\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
*/
