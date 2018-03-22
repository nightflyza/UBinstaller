#!/usr/local/bin/php
<?php

if ($argc >= 2) {
    $option = $argv[1];
    $command = "/usr/bin/uptime";
    $raw = shell_exec($command);
    $raw = trim($raw);
    $loadavg = explode('load averages:', $raw);
    $loadavg = $loadavg[1];
    $loadavg = explode(',', $loadavg);
    $loadavg = trim($loadavg[0]);
    print($loadavg);

    if ($loadavg >= $option) {
        $curdate = date("Y-m-d H:i:s");
        shell_exec('echo "RENATLA ' . $curdate . '" >> /var/log/torture.log');
        shell_exec('/bin/renat');
    }
} else {
    print('At least one option required. Usage example: lactrl 4' . PHP_EOL);
}

?>