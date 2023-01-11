<?php
/**
 * Copyright (C) 2022 OpenMediaVault Plugin Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
class OMVRpcServiceCpuTemp extends \OMV\Rpc\ServiceAbstract
{
    public function getName()
    {
        return "CpuTemp";
    }

    public function initialize()
    {
        $this->registerMethod("get");
        $this->registerMethod("getSensors");
    }

    public function get($params, $context)
    {
        // Validate the RPC caller context.
        $this->validateMethodContext($context, ["role" => OMV_ROLE_ADMINISTRATOR]);
        $cmd = new \OMV\System\Process("cat /sys/devices/virtual/thermal/thermal_zone0/temp");
        $cmd->execute($output, $exitStatus);
        return [
            "cputemp" => intval($output[0]) / 1000
        ];
    }

    public function getSensors($params, $context)
    {
        // Validate the RPC caller context.
        $this->validateMethodContext($context, ["role" => OMV_ROLE_ADMINISTRATOR]);
        $output = [];
        $temps = [];
        if (file_exists("/usr/bin/sensors")) {
            $cmd = new \OMV\System\Process("sensors","| cut -d'(' -f1");
            $cmd->execute($output, $exitStatus);

            foreach (array_filter($output) as $line) {
                if (strpos($line, ':') > 0) {
                    $temps[] = trim($line);
                } else {
                    $temps[] = '<br/><b>'.trim($line).'</b><br/>';
                }
            }
        } else {
            $temps[] = "lm-sensors package is not installed and/or configured.";
        }
        return (implode('<br/>', $temps));
    }
}
