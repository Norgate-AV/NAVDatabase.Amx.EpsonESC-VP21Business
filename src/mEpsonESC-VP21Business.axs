MODULE_NAME='mEpsonESC-VP21Business'    (
                                            dev vdvObject,
                                            dev dvPort
                                        )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.SocketUtils.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant long TL_DRIVE    = 1
constant long TL_SOCKET_CHECK = 2

constant integer REQUIRED_POWER_ON    = 1
constant integer REQUIRED_POWER_OFF    = 2

constant integer ACTUAL_POWER_ON    = 1
constant integer ACTUAL_POWER_OFF    = 2
constant integer ACTUAL_POWER_WARMING    = 3
constant integer ACTUAL_POWER_COOLING    = 4
constant integer ACTUAL_POWER_ABNORMAL_STANDBY    = 5

constant integer REQUIRED_INPUT_VGA_1    = 1
constant integer REQUIRED_INPUT_VGA_2    = 2
constant integer REQUIRED_INPUT_RGBHV_1    = 3
constant integer REQUIRED_INPUT_RGBHV_2    = 4
constant integer REQUIRED_INPUT_HDMI_1    = 5
constant integer REQUIRED_INPUT_DVI_1    = 6
constant integer REQUIRED_INPUT_SVIDEO_1    = 7
constant integer REQUIRED_INPUT_VIDEO_1    = 8
constant integer REQUIRED_INPUT_VIDEO_2    = 9
constant integer REQUIRED_INPUT_HD_BASE_T    = 10
constant integer REQUIRED_INPUT_SDI_1    = 11

constant integer ACTUAL_INPUT_VGA_1    = 1
constant integer ACTUAL_INPUT_VGA_2    = 2
constant integer ACTUAL_INPUT_RGBHV_1    = 3
constant integer ACTUAL_INPUT_RGBHV_2    = 4
constant integer ACTUAL_INPUT_HDMI_1    = 5
constant integer ACTUAL_INPUT_DVI_1    = 6
constant integer ACTUAL_INPUT_SVIDEO_1    = 7
constant integer ACTUAL_INPUT_VIDEO_1    = 8
constant integer ACTUAL_INPUT_VIDEO_2    = 9
constant integer ACTUAL_INPUT_HD_BASE_T    = 10
constant integer ACTUAL_INPUT_SDI_1    = 11

constant integer INPUT_COMMAND_BYTE_VGA_1    = $11
constant integer INPUT_COMMAND_BYTE_VGA_2    = $21
constant integer INPUT_COMMAND_BYTE_RGBHV_1    = $B1
constant integer INPUT_COMMAND_BYTE_RGBHV_2    = $B4
constant integer INPUT_COMMAND_BYTE_HDMI    = $30
constant integer INPUT_COMMAND_BYTE_DVI        = $A0
constant integer INPUT_COMMAND_BYTE_SVIDEO    = $42
constant integer INPUT_COMMAND_BYTE_VIDEO_1    = $45
constant integer INPUT_COMMAND_BYTE_VIDEO_2    = $41
constant integer INPUT_COMMAND_BYTE_HD_BASE_T    = $80
constant integer INPUT_COMMAND_BYTE_SDI_1    = $60
constant integer INPUT_COMMAND_BYTES[]  =   {
                                                    INPUT_COMMAND_BYTE_VGA_1,
                                                    INPUT_COMMAND_BYTE_VGA_2,
                                                    INPUT_COMMAND_BYTE_RGBHV_1,
                                                    INPUT_COMMAND_BYTE_RGBHV_2,
                                                    INPUT_COMMAND_BYTE_HDMI,
                                                    INPUT_COMMAND_BYTE_DVI,
                                                    INPUT_COMMAND_BYTE_SVIDEO,
                                                    INPUT_COMMAND_BYTE_VIDEO_1,
                                                    INPUT_COMMAND_BYTE_VIDEO_2,
                                                    INPUT_COMMAND_BYTE_HD_BASE_T,
                                                    INPUT_COMMAND_BYTE_SDI_1
                                                }

constant integer GET_POWER    = 1
constant integer GET_INPUT    = 2
constant integer GET_LAMP    = 3
constant integer GET_MUTE    = 4
constant integer GET_VOLUME    = 5

constant integer REQUIRED_MUTE_ON    = 1
constant integer REQUIRED_MUTE_OFF    = 2

constant integer ACTUAL_MUTE_ON    = 1
constant integer ACTUAL_MUTE_OFF    = 2

constant integer MAX_VOLUME = 31
constant integer MIN_VOLUME = 0

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile long driveTicks[] = { 200 }
volatile long socketCheck[] = { 3000 }    //3 seconds

volatile _NAVProjector uProj

volatile integer commandBusy
volatile integer loop

volatile integer semaphore
volatile char rxBuffer[NAV_MAX_BUFFER]

volatile integer pollSequence = GET_POWER

volatile char ipAddress[15]
volatile integer ipPort
volatile integer ipConnected

volatile integer communicating
volatile integer initialized

volatile integer autoAdjustRequired

volatile integer inputInitialized = false

volatile integer queryLockOut

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function SendStringRaw(char payload[]) {
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO,
                                            dvPort,
                                            payload))

    send_string dvPort, "payload"
}


define_function SendString(char payload[]) {
    SendStringRaw("payload, NAV_CR")
}


define_function SendQuery(integer query) {
    switch (query) {
        case GET_POWER: { SendString("'PWR?'") }
        case GET_INPUT: { SendString("'SOURCE?'") }
        case GET_LAMP: { SendString("'LAMP?'") }
        case GET_MUTE: { SendString("'MUTE?'") }
        case GET_VOLUME: { SendString("'VOL?'") }
    }
}


define_function TimeOut() {
    cancel_wait 'CommsTimeOut'
    wait 300 'CommsTimeOut' { communicating = false }
}


define_function SetPower(integer state) {
    switch (state) {
        case REQUIRED_POWER_ON: { SendString("'PWR ON'") }
        case REQUIRED_POWER_OFF: { SendString("'PWR OFF'") }
    }
}


define_function SetInput(integer input) { SendString("'SOURCE ', itohex(INPUT_COMMAND_BYTES[input])") }


define_function SetVolume(sinteger value) { SendString("'VOL ', itoa(value)") }


define_function SetMute(integer state) {
    switch (state) {
        case REQUIRED_MUTE_ON: { SendString("'MUTE ON'") }
        case REQUIRED_MUTE_OFF: { SendString("'MUTE OFF'") }
    }
}


define_function Process() {
    stack_var char data[NAV_MAX_BUFFER]
    stack_var char cmd[10]

    if (semaphore) {
        return
    }

    semaphore = true

    while (length_array(rxBuffer) && NAVContains(rxBuffer, "':'")) {
        data = remove_string(rxBuffer, "':'", 1)

        if (!length_array(data)) {
            continue
        }

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_PARSING_STRING_FROM,
                                                dvPort,
                                                data))

        data = NAVStripCharsFromRight(data, 1)    //Removes :

        if (!length_array(data)) {
            continue
        }

        data = NAVStripCharsFromRight(data, 1)    //Removes CR

        if (!length_array(data)) {
            continue
        }

        cmd = NAVStripCharsFromRight(remove_string(data, '=', 1), 1)

        switch (cmd) {
            case 'PWR': {
                switch (data) {
                    case '00':
                    case '04': { uProj.Display.PowerState.Actual = ACTUAL_POWER_OFF; pollSequence = GET_LAMP }
                    case '01': {
                        uProj.Display.PowerState.Actual = ACTUAL_POWER_ON

                        select {
                            active (!inputInitialized): {
                                pollSequence = GET_INPUT
                            }
                            active (true): {
                                pollSequence = GET_LAMP
                            }
                        }
                    }
                    case '02': { uProj.Display.PowerState.Actual = ACTUAL_POWER_WARMING; pollSequence = GET_LAMP }
                    case '03': { uProj.Display.PowerState.Actual = ACTUAL_POWER_COOLING; pollSequence = GET_LAMP }
                    case '05': { uProj.Display.PowerState.Actual = ACTUAL_POWER_ABNORMAL_STANDBY; pollSequence = GET_LAMP }
                }
            }
            case 'SOURCE': {
                switch (hextoi(data)) {
                    case INPUT_COMMAND_BYTE_VGA_1: { uProj.Display.Input.Actual = ACTUAL_INPUT_VGA_1; send_string vdvObject, "'INPUT-VGA, 1'" }
                    case INPUT_COMMAND_BYTE_VGA_2: { uProj.Display.Input.Actual = ACTUAL_INPUT_VGA_2; send_string vdvObject, "'INPUT-VGA, 2'" }
                    case INPUT_COMMAND_BYTE_RGBHV_1: { uProj.Display.Input.Actual = ACTUAL_INPUT_RGBHV_1; send_string vdvObject, "'INPUT-RGB, 1'" }
                    case INPUT_COMMAND_BYTE_RGBHV_2: { uProj.Display.Input.Actual = ACTUAL_INPUT_RGBHV_2; send_string vdvObject, "'INPUT-RGB, 2'" }
                    case INPUT_COMMAND_BYTE_HDMI: { uProj.Display.Input.Actual = ACTUAL_INPUT_HDMI_1; send_string vdvObject, "'INPUT-HDMI, 1'" }
                    case INPUT_COMMAND_BYTE_DVI: { uProj.Display.Input.Actual = ACTUAL_INPUT_DVI_1; send_string vdvObject, "'INPUT-DVI, 1'" }
                    case INPUT_COMMAND_BYTE_SVIDEO: { uProj.Display.Input.Actual = ACTUAL_INPUT_SVIDEO_1; send_string vdvObject, "'INPUT-S-VIDEO, 1'" }
                    case INPUT_COMMAND_BYTE_VIDEO_1: { uProj.Display.Input.Actual = ACTUAL_INPUT_VIDEO_1; send_string vdvObject, "'INPUT-COMPOSITE, 1'" }
                    case INPUT_COMMAND_BYTE_VIDEO_2: { uProj.Display.Input.Actual = ACTUAL_INPUT_VIDEO_2; send_string vdvObject, "'INPUT-COMPOSITE, 2'" }
                    case INPUT_COMMAND_BYTE_HD_BASE_T: { uProj.Display.Input.Actual = ACTUAL_INPUT_HD_BASE_T; send_string vdvObject, "'INPUT-HD_BASE_T, 1'" }
                    case INPUT_COMMAND_BYTE_SDI_1: { uProj.Display.Input.Actual = ACTUAL_INPUT_SDI_1; send_string vdvObject, "'INPUT-SDI, 1'" }
                }

                pollSequence = GET_POWER
            }
            case 'LAMP': {
                if (!NAVContains(data, ' ')) {
                    if (uProj.LampHours[1].Actual != atoi(data)) {
                        uProj.LampHours[1].Actual = atoi(data)
                        send_string vdvObject, "'LAMPTIME-1, ', itoa(uProj.LampHours[1].Actual)"
                    }
                }
                else {
                    stack_var integer temp[2]
                    stack_var integer x

                    temp[1] = atoi(NAVStripCharsFromRight(remove_string(data, ' ', 1), 1))
                    temp[2] = atoi(data)

                    for (x = 1; x <= 2; x++) {
                        if (uProj.LampHours[x].Actual != temp[x]) {
                            uProj.LampHours[x].Actual = temp[x]
                            send_string vdvObject, "'LAMPTIME-', itoa(x), ', ', itoa(uProj.LampHours[x].Actual)"
                            send_level vdvObject, x + 10, uProj.LampHours[x].Actual
                        }
                    }
                }

                pollSequence = GET_POWER
            }
            case 'MUTE': {
                switch (data) {
                    case 'ON': { uProj.Display.Volume.Mute.Actual = ACTUAL_MUTE_ON }
                    case 'OFF': { uProj.Display.Volume.Mute.Actual = ACTUAL_MUTE_OFF }
                }

                pollSequence = GET_POWER
            }
            case 'VOL': {
                uProj.Display.Volume.Level.Actual = atoi(data)
                pollSequence = GET_POWER
            }
            case 'ERR': {}
        }
    }

    semaphore = false
}


define_function Drive() {
    loop++

    switch (loop) {
        case 1:
        case 6:
        case 11:
        case 16: { if (!queryLockOut) SendQuery(pollSequence); return }
        case 21: { loop = 0; return }
        default: {
            if (commandBusy) { return }
            if (uProj.Display.PowerState.Required && (uProj.Display.PowerState.Required == uProj.Display.PowerState.Actual)) { uProj.Display.PowerState.Required = 0; }
            if (uProj.Display.Input.Required && (uProj.Display.Input.Required == uProj.Display.Input.Actual)) { uProj.Display.Input.Required = 0; }
            if (uProj.Display.VideoMute.Required && (uProj.Display.VideoMute.Required == uProj.Display.VideoMute.Actual)) { uProj.Display.VideoMute.Required = 0; }
            if ((uProj.Display.Volume.Level.Required >= 0) && (uProj.Display.Volume.Level.Required == uProj.Display.Volume.Level.Actual)) { uProj.Display.Volume.Level.Required = -1; }

            if (uProj.Display.Volume.Mute.Required && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (uProj.Display.Volume.Mute.Required != uProj.Display.Volume.Mute.Actual) && communicating) {
                commandBusy = true
                SetMute(uProj.Display.Volume.Mute.Required);
                wait 10 commandBusy = false
                pollSequence = GET_MUTE;
                return
            }

            if (uProj.Display.PowerState.Required && (uProj.Display.PowerState.Required != uProj.Display.PowerState.Actual) && (uProj.Display.PowerState.Actual != ACTUAL_POWER_WARMING) && (uProj.Display.PowerState.Actual != ACTUAL_POWER_COOLING) && communicating) {
                commandBusy = true
                //queryLockOut = true
                SetPower(uProj.Display.PowerState.Required)
                wait 80 commandBusy = false
                pollSequence = GET_POWER
                return
            }

            if (uProj.Display.Input.Required && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (uProj.Display.Input.Required != uProj.Display.Input.Actual) && communicating) {
                commandBusy = true
                SetInput(uProj.Display.Input.Required)
                wait 10 commandBusy = false
                pollSequence = GET_INPUT
                return
            }

            if (autoAdjustRequired && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && communicating) {
                SendString('KEY 4A')
                autoAdjustRequired = false
            }

            if ([vdvObject, VOL_UP] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (uProj.Display.Volume.Level.Actual < MAX_VOLUME) && communicating) {
                SendString('VOL INC')
            }

            if ([vdvObject, VOL_DN] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (uProj.Display.Volume.Level.Actual > MIN_VOLUME) && communicating) {
                SendString('VOL DEC')
            }

            if ((uProj.Display.Volume.Level.Required >= 0) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (uProj.Display.Volume.Level.Required != uProj.Display.Volume.Level.Actual) && communicating) {
                commandBusy = true
                SetVolume(uProj.Display.Volume.Level.Required);
                pollSequence = GET_VOLUME;
                return
            }

            if ([vdvObject, 44] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && communicating) {
                SendString('KEY 03'); commandBusy = true; wait 5 commandBusy = false    //Menu
            }

            if ([vdvObject, 45] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && communicating) {
                SendString('KEY 35'); commandBusy = true; wait 5 commandBusy = false    //Up
            }

            if ([vdvObject, 46] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && communicating) {
                SendString('KEY 36'); commandBusy = true; wait 5 commandBusy = false    //Down
            }

            if ([vdvObject, 47] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && communicating) {
                SendString('KEY 37'); commandBusy = true; wait 5 commandBusy = false    //Left
            }

            if ([vdvObject, 48] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && communicating) {
                SendString('KEY 38'); commandBusy = true; wait 5 commandBusy = false    //Right
            }

            if ([vdvObject, 49] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && communicating) {
                SendString('KEY 49'); commandBusy = true; wait 5 commandBusy = false    //Enter
            }
        }
    }
}


define_function MaintainSocketConnection() {
    if (ipConnected) {
        return
    }

    NAVClientSocketOpen(dvPort.PORT, ipAddress, ipPort, IP_TCP)
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort, rxBuffer

    uProj.Display.Volume.Level.Required = -1
    uProj.Display.Volume.Level.Actual = -1
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        if (data.device.number != 0) {
            NAVCommand(data.device, "'SET BAUD 9600, N, 8, 1 485 DISABLE'")
            NAVCommand(data.device, "'B9MOFF'")
            NAVCommand(data.device, "'CHARD-0'")
            NAVCommand(data.device, "'CHARDM-0'")
            NAVCommand(data.device, "'HSOFF'")
        }

        if (data.device.number == 0) {
            ipConnected = true
        }

        NAVTimelineStart(TL_DRIVE, driveTicks, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
    }
    string: {
        communicating = true
        initialized = true

        TimeOut()

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM,
                                                dvPort,
                                                data.text))

        if (!semaphore) { Process() }
    }
    offline: {
        if (data.device.number == 0) {
            NAVClientSocketClose(dvPort.port)
            ipConnected = false
        }
    }
    onerror: {
        if (data.device.number == 0) {

        }
    }
}


data_event[vdvObject] {
    online: {
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY, MONITOR_ASSET_DESCRIPTION,Video Projector'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY, MONITOR_ASSET_MANUFACTURER_URL,www.epson.com'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY, MONITOR_ASSET_MANUFACTURER_NAME,EPSON'")
    }
    command: {
        stack_var char cmdHeader[NAV_MAX_CHARS]
        stack_var char cmdParam[2][NAV_MAX_CHARS]

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM,
                                                data.device,
                                                data.text))

        cmdHeader = DuetParseCmdHeader(data.text)
        cmdParam[1] = DuetParseCmdParam(data.text)
        cmdParam[2] = DuetParseCmdParam(data.text)

        switch (cmdHeader) {
            case 'PROPERTY': {
                switch (cmdParam[1]) {
                    case 'IP_ADDRESS': {
                        ipAddress = cmdParam[2]
                    }
                    case 'TCP_PORT': {
                        ipPort = atoi(cmdParam[2])
                        NAVTimelineStart(TL_SOCKET_CHECK, socketCheck, timeline_absolute, timeline_repeat)
                    }
                }
            }
            case 'PASSTHRU': { SendString(cmdParam[1]) }

            case 'POWER': {
                switch (cmdParam[1]) {
                    case 'ON': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; Drive() }
                    case 'OFF': { uProj.Display.PowerState.Required = REQUIRED_POWER_OFF; uProj.Display.Input.Required = 0; Drive() }
                }
            }
            case 'ADJUST': { autoAdjustRequired = true; Drive() }
            case 'INPUT': {
                switch (cmdParam[1]) {
                    case 'VGA': {
                        switch (cmdParam[2]) {
                            case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_VGA_1; Drive() }
                            case '2': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_VGA_2; Drive() }
                        }
                    }
                    case 'RGB': {
                        switch (cmdParam[2]) {
                            case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_RGBHV_1; Drive() }
                            case '2': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_RGBHV_2; Drive() }
                        }
                    }
                    case 'HDMI': {
                        switch (cmdParam[2]) {
                            case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_HDMI_1; Drive() }
                        }
                    }
                    case 'DVI': {
                        switch (cmdParam[2]) {
                            case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_DVI_1; Drive() }
                        }
                    }
                    case 'SDI': {
                        switch (cmdParam[2]) {
                            case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_SDI_1; Drive() }
                        }
                    }
                    case 'S-VIDEO': {
                        switch (cmdParam[2]) {
                            case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_SVIDEO_1; Drive() }
                        }
                    }
                    case 'HD_BASE_T': {
                        switch (cmdParam[2]) {
                            case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_HD_BASE_T; Drive() }
                        }
                    }
                    case 'COMPOSITE': {
                        switch (cmdParam[2]) {
                            case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_VIDEO_1; Drive() }
                            case '2': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_VIDEO_2; Drive() }
                        }
                    }
                }
            }
            case 'MUTE': {
                NAVErrorLog(NAV_LOG_LEVEL_DEBUG, 'RECEIVED MUTE COMMAND')

                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, 'RECEIVED MUTE COMMAND')

                    switch (cmdParam[1]) {
                        case 'ON': { uProj.Display.Volume.Mute.Required = REQUIRED_MUTE_ON; Drive() }
                        case 'OFF': { uProj.Display.Volume.Mute.Required = REQUIRED_MUTE_OFF; Drive() }
                    }
                }
            }
            case 'ASPECT': {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    switch (cmdParam[1]) {
                        case '4:3': { SendString('ASPECT 10') }
                        case '16:9': { SendString('ASPECT 20') }
                        case 'FULL': { SendString('ASPECT 40') }
                        case 'NORMAL': { SendString('ASPECT 00') }
                    }
                }
            }
        }
    }
}


channel_event[vdvObject, 0] {
    on: {
        switch (channel.channel) {
            case POWER: {
                if (uProj.Display.PowerState.Required) {
                    switch (uProj.Display.PowerState.Required) {
                        case REQUIRED_POWER_ON: { uProj.Display.PowerState.Required = REQUIRED_POWER_OFF; uProj.Display.Input.Required = 0; Drive() }
                        case REQUIRED_POWER_OFF: { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; Drive() }
                    }
                }
                else {
                    switch (uProj.Display.PowerState.Actual) {
                        case ACTUAL_POWER_ON: { uProj.Display.PowerState.Required = REQUIRED_POWER_OFF; uProj.Display.Input.Required = 0; Drive() }
                        case ACTUAL_POWER_OFF: { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; Drive() }
                    }
                }
            }
            case PWR_ON: { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; Drive() }
            case PWR_OFF: { uProj.Display.PowerState.Required = REQUIRED_POWER_OFF; uProj.Display.Input.Required = 0; Drive() }
            case VOL_MUTE: {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    if (uProj.Display.Volume.Mute.Required) {
                        switch (uProj.Display.Volume.Mute.Required) {
                            case REQUIRED_MUTE_ON: { uProj.Display.Volume.Mute.Required = REQUIRED_MUTE_OFF; Drive() }
                            case REQUIRED_MUTE_OFF: { uProj.Display.Volume.Mute.Required = REQUIRED_MUTE_ON; Drive() }
                        }
                    }
                    else {
                        switch (uProj.Display.Volume.Mute.Actual) {
                            case ACTUAL_MUTE_ON: { uProj.Display.Volume.Mute.Required = REQUIRED_MUTE_OFF; Drive() }
                            case ACTUAL_MUTE_OFF: { uProj.Display.Volume.Mute.Required = REQUIRED_MUTE_ON; Drive() }
                        }
                    }
                }
            }
            case PIC_MUTE_ON: {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    uProj.Display.Volume.Mute.Required = REQUIRED_MUTE_ON; Drive()
                }
            }
        }
    }
    off: {
        switch (channel.channel) {
            case PIC_MUTE_ON: {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    uProj.Display.Volume.Mute.Required = REQUIRED_MUTE_OFF; Drive()
                }
            }
        }
    }
}


timeline_event[TL_DRIVE] { Drive() }


timeline_event[TL_SOCKET_CHECK] { MaintainSocketConnection() }


timeline_event[TL_NAV_FEEDBACK] {
    [vdvObject, DEVICE_COMMUNICATING]    = (communicating)
    [vdvObject, DATA_INITIALIZED]    = (initialized)
    [vdvObject, VOL_MUTE_FB] = (uProj.Display.VideoMute.Actual == ACTUAL_MUTE_ON)
    [vdvObject, POWER_FB] = (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON)
    [vdvObject, LAMP_WARMING_FB]    = (uProj.Display.PowerState.Actual = ACTUAL_POWER_WARMING)
    [vdvObject, LAMP_COOLING_FB]    = (uProj.Display.PowerState.Actual = ACTUAL_POWER_COOLING)
    [vdvObject, 31]    = ((uProj.Display.Input.Actual == ACTUAL_INPUT_VGA_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
    [vdvObject, 32]    = ((uProj.Display.Input.Actual == ACTUAL_INPUT_VGA_2) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
    [vdvObject, 33]    = ((uProj.Display.Input.Actual == ACTUAL_INPUT_RGBHV_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
    [vdvObject, 34]    = ((uProj.Display.Input.Actual == ACTUAL_INPUT_RGBHV_2) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
    [vdvObject, 35]    = ((uProj.Display.Input.Actual == ACTUAL_INPUT_HDMI_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
    [vdvObject, 36]    = ((uProj.Display.Input.Actual == ACTUAL_INPUT_DVI_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
    [vdvObject, 37]    = ((uProj.Display.Input.Actual == ACTUAL_INPUT_SVIDEO_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
    [vdvObject, 38]    = ((uProj.Display.Input.Actual == ACTUAL_INPUT_VIDEO_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
    [vdvObject, 39]    = ((uProj.Display.Input.Actual == ACTUAL_INPUT_HD_BASE_T) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
    [vdvObject, 40]    = ((uProj.Display.Input.Actual == ACTUAL_INPUT_SDI_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
}

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

