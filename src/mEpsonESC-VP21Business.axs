MODULE_NAME='mEpsonESC-VP21Business'	(
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

constant long TL_DRIVE	= 1
constant long TL_IP_CHECK = 2

constant integer REQUIRED_POWER_ON	= 1
constant integer REQUIRED_POWER_OFF	= 2

constant integer ACTUAL_POWER_ON	= 1
constant integer ACTUAL_POWER_OFF	= 2
constant integer ACTUAL_POWER_WARMING	= 3
constant integer ACTUAL_POWER_COOLING	= 4
constant integer ACTUAL_POWER_ABNORMAL_STANDBY	= 5

constant integer REQUIRED_INPUT_VGA_1	= 1
constant integer REQUIRED_INPUT_VGA_2	= 2
constant integer REQUIRED_INPUT_RGBHV_1	= 3
constant integer REQUIRED_INPUT_RGBHV_2	= 4
constant integer REQUIRED_INPUT_HDMI_1	= 5
constant integer REQUIRED_INPUT_DVI_1	= 6
constant integer REQUIRED_INPUT_SVIDEO_1	= 7
constant integer REQUIRED_INPUT_VIDEO_1	= 8
constant integer REQUIRED_INPUT_VIDEO_2	= 9
constant integer REQUIRED_INPUT_HD_BASE_T	= 10
constant integer REQUIRED_INPUT_SDI_1	= 11

constant integer ACTUAL_INPUT_VGA_1	= 1
constant integer ACTUAL_INPUT_VGA_2	= 2
constant integer ACTUAL_INPUT_RGBHV_1	= 3
constant integer ACTUAL_INPUT_RGBHV_2	= 4
constant integer ACTUAL_INPUT_HDMI_1	= 5
constant integer ACTUAL_INPUT_DVI_1	= 6
constant integer ACTUAL_INPUT_SVIDEO_1	= 7
constant integer ACTUAL_INPUT_VIDEO_1	= 8
constant integer ACTUAL_INPUT_VIDEO_2	= 9
constant integer ACTUAL_INPUT_HD_BASE_T	= 10
constant integer ACTUAL_INPUT_SDI_1	= 11

constant integer INPUT_COMMAND_BYTE_VGA_1	= $11
constant integer INPUT_COMMAND_BYTE_VGA_2	= $21
constant integer INPUT_COMMAND_BYTE_RGBHV_1	= $B1
constant integer INPUT_COMMAND_BYTE_RGBHV_2	= $B4
constant integer INPUT_COMMAND_BYTE_HDMI	= $30
constant integer INPUT_COMMAND_BYTE_DVI		= $A0
constant integer INPUT_COMMAND_BYTE_SVIDEO	= $42
constant integer INPUT_COMMAND_BYTE_VIDEO_1	= $45
constant integer INPUT_COMMAND_BYTE_VIDEO_2	= $41
constant integer INPUT_COMMAND_BYTE_HD_BASE_T	= $80
constant integer INPUT_COMMAND_BYTE_SDI_1	= $60
constant integer INPUT_COMMAND_BYTES[]	= { INPUT_COMMAND_BYTE_VGA_1,
					    INPUT_COMMAND_BYTE_VGA_2,
					    INPUT_COMMAND_BYTE_RGBHV_1,
					    INPUT_COMMAND_BYTE_RGBHV_2,
					    INPUT_COMMAND_BYTE_HDMI,
					    INPUT_COMMAND_BYTE_DVI,
					    INPUT_COMMAND_BYTE_SVIDEO,
					    INPUT_COMMAND_BYTE_VIDEO_1,
					    INPUT_COMMAND_BYTE_VIDEO_2,
					    INPUT_COMMAND_BYTE_HD_BASE_T,
					    INPUT_COMMAND_BYTE_SDI_1 }

constant integer GET_POWER	= 1
constant integer GET_INPUT	= 2
constant integer GET_LAMP	= 3
constant integer GET_MUTE	= 4
constant integer GET_VOLUME	= 5

constant integer REQUIRED_MUTE_ON	= 1
constant integer REQUIRED_MUTE_OFF	= 2

constant integer ACTUAL_MUTE_ON	= 1
constant integer ACTUAL_MUTE_OFF	= 2

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
volatile long ltDrive[] = { 200 }
volatile long ltIPCheck[] = { 3000 }	//3 seconds

volatile _NAVProjector uProj

volatile integer iCommandBusy
volatile integer iLoop

volatile integer iSemaphore
volatile char cRxBuffer[NAV_MAX_BUFFER]

volatile integer iModuleEnabled

volatile integer iPollSequence = GET_POWER

volatile char cIPAddress[15]
volatile integer iTCPPort
volatile integer iIPConnected

volatile integer iCommunicating
volatile integer iInitialized

volatile integer iAutoAdjustRequired

volatile integer iInputInitialized = false

volatile integer iQueryLockOut

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
define_function SendStringRaw(char cParam[]) {
    NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO, dvPort, cParam))
    send_string dvPort,"cParam"
}

define_function SendString(char cParam[]) {
    SendStringRaw("cParam,NAV_CR")
}

define_function SendQuery(integer iParam) {
    switch (iParam) {
	case GET_POWER: { SendString("'PWR?'") }
	case GET_INPUT: { SendString("'SOURCE?'") }
	case GET_LAMP: { SendString("'LAMP?'") }
	case GET_MUTE: { SendString("'MUTE?'") }
	case GET_VOLUME: { SendString("'VOL?'") }
    }
}

define_function TimeOut() {
    cancel_wait 'CommsTimeOut'
    wait 300 'CommsTimeOut' { iCommunicating = false }
}

define_function SetPower(integer iParam) {
    switch (iParam) {
	case REQUIRED_POWER_ON: { SendString("'PWR ON'") }
	case REQUIRED_POWER_OFF: { SendString("'PWR OFF'") }
    }
}

define_function SetInput(integer iParam) { SendString("'SOURCE ',itohex(INPUT_COMMAND_BYTES[iParam])") }

define_function SetVolume(sinteger siParam) { SendString("'VOL ',itoa(siParam)") }

define_function SetMute(integer iParam) {
    switch (iParam) {
	case REQUIRED_MUTE_ON: { SendString("'MUTE ON'") }
	case REQUIRED_MUTE_OFF: { SendString("'MUTE OFF'") }
    }
}

define_function Process() {
    stack_var char cTemp[NAV_MAX_BUFFER]
    iSemaphore = true
    while (length_array(cRxBuffer) && NAVContains(cRxBuffer,"':'")) {
	cTemp = remove_string(cRxBuffer,"':'",1)
	if (length_array(cTemp)) {
	    NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_PARSING_STRING_FROM, dvPort, cTemp))
	    cTemp = NAVStripCharsFromRight(cTemp, 1)	//Removes :
	    if (length_array(cTemp)) {
		cTemp = NAVStripCharsFromRight(cTemp, 1)	//Removes CR
		if (length_array(cTemp)) {
		    stack_var char cAtt[10]
		    cAtt = NAVStripCharsFromRight(remove_string(cTemp,'=',1),1)
		    switch (cAtt) {
			case 'PWR': {
			    switch (cTemp) {
				case '00':
				case '04': { uProj.Display.PowerState.Actual = ACTUAL_POWER_OFF; iPollSequence = GET_LAMP }
				case '01': {
				    uProj.Display.PowerState.Actual = ACTUAL_POWER_ON

				    select {
					active (!iInputInitialized): {
					    iPollSequence = GET_INPUT
					}
					active (1): {
					    iPollSequence = GET_LAMP
					}
				    }
				}
				case '02': { uProj.Display.PowerState.Actual = ACTUAL_POWER_WARMING; iPollSequence = GET_LAMP }
				case '03': { uProj.Display.PowerState.Actual = ACTUAL_POWER_COOLING; iPollSequence = GET_LAMP }
				case '05': { uProj.Display.PowerState.Actual = ACTUAL_POWER_ABNORMAL_STANDBY; iPollSequence = GET_LAMP }
			    }


			}
			case 'SOURCE': {
			    switch (hextoi(cTemp)) {
				case INPUT_COMMAND_BYTE_VGA_1: { uProj.Display.Input.Actual = ACTUAL_INPUT_VGA_1; send_string vdvObject,"'INPUT-VGA,1'" }
				case INPUT_COMMAND_BYTE_VGA_2: { uProj.Display.Input.Actual = ACTUAL_INPUT_VGA_2; send_string vdvObject,"'INPUT-VGA,2'" }
				case INPUT_COMMAND_BYTE_RGBHV_1: { uProj.Display.Input.Actual = ACTUAL_INPUT_RGBHV_1; send_string vdvObject,"'INPUT-RGB,1'" }
				case INPUT_COMMAND_BYTE_RGBHV_2: { uProj.Display.Input.Actual = ACTUAL_INPUT_RGBHV_2; send_string vdvObject,"'INPUT-RGB,2'" }
				case INPUT_COMMAND_BYTE_HDMI: { uProj.Display.Input.Actual = ACTUAL_INPUT_HDMI_1; send_string vdvObject,"'INPUT-HDMI,1'" }
				case INPUT_COMMAND_BYTE_DVI: { uProj.Display.Input.Actual = ACTUAL_INPUT_DVI_1; send_string vdvObject,"'INPUT-DVI,1'" }
				case INPUT_COMMAND_BYTE_SVIDEO: { uProj.Display.Input.Actual = ACTUAL_INPUT_SVIDEO_1; send_string vdvObject,"'INPUT-S-VIDEO,1'" }
				case INPUT_COMMAND_BYTE_VIDEO_1: { uProj.Display.Input.Actual = ACTUAL_INPUT_VIDEO_1; send_string vdvObject,"'INPUT-COMPOSITE,1'" }
				case INPUT_COMMAND_BYTE_VIDEO_2: { uProj.Display.Input.Actual = ACTUAL_INPUT_VIDEO_2; send_string vdvObject,"'INPUT-COMPOSITE,2'" }
				case INPUT_COMMAND_BYTE_HD_BASE_T: { uProj.Display.Input.Actual = ACTUAL_INPUT_HD_BASE_T; send_string vdvObject,"'INPUT-HD_BASE_T,1'" }
				case INPUT_COMMAND_BYTE_SDI_1: { uProj.Display.Input.Actual = ACTUAL_INPUT_SDI_1; send_string vdvObject,"'INPUT-SDI,1'" }
			    }

			    iPollSequence = GET_POWER
			}
			case 'LAMP': {
			    if (!NAVContains(cTemp,' ')) {
				if (uProj.LampHours[1].Actual <> atoi(cTemp)) {
				    uProj.LampHours[1].Actual = atoi(cTemp)
				    send_string vdvObject,"'LAMPTIME-1,',itoa(uProj.LampHours[1].Actual)"
				}
			    }else {
				stack_var integer iTemp[2]
				stack_var integer x
				iTemp[1] = atoi(NAVStripCharsFromRight(remove_string(cTemp,' ',1),1))
				iTemp[2] = atoi(cTemp)
				for (x = 1; x <= 2; x++) {
				    if (uProj.LampHours[x].Actual <> iTemp[x]) {
					uProj.LampHours[x].Actual = iTemp[x]
					send_string vdvObject,"'LAMPTIME-',itoa(x),',',itoa(uProj.LampHours[x].Actual)"
					send_level vdvObject,x + 10,uProj.LampHours[x].Actual
				    }
				}
			    }

			    iPollSequence = GET_POWER
			}
			case 'MUTE': {
			    switch (cTemp) {
				case 'ON': { uProj.Display.Volume.Mute.Actual = ACTUAL_MUTE_ON }
				case 'OFF': { uProj.Display.Volume.Mute.Actual = ACTUAL_MUTE_OFF }
			    }

			    iPollSequence = GET_POWER
			}
			case 'VOL': {
			    uProj.Display.Volume.Level.Actual = atoi(cTemp)
			    iPollSequence = GET_POWER
			}
			case 'ERR': {
			    //Error
			    //What is the Error?
			    //SendString('ERR?')
			}
		    }
		}else {

		}
	    }else {
		//Null Response
	    }
	}
    }

    iSemaphore = false
}

define_function Drive() {
    iLoop++
    switch (iLoop) {
	case 1:
	case 6:
	case 11:
	case 16: { if (!iQueryLockOut) SendQuery(iPollSequence); return }
	case 21: { iLoop = 1; return }
	default: {
	    if (iCommandBusy) { return }
	    if (uProj.Display.PowerState.Required && (uProj.Display.PowerState.Required == uProj.Display.PowerState.Actual)) { uProj.Display.PowerState.Required = 0; }
	    if (uProj.Display.Input.Required && (uProj.Display.Input.Required == uProj.Display.Input.Actual)) { uProj.Display.Input.Required = 0; }
	    if (uProj.Display.VideoMute.Required && (uProj.Display.VideoMute.Required == uProj.Display.VideoMute.Actual)) { uProj.Display.VideoMute.Required = 0; }
	    if ((uProj.Display.Volume.Level.Required >= 0) && (uProj.Display.Volume.Level.Required == uProj.Display.Volume.Level.Actual)) { uProj.Display.Volume.Level.Required = -1; }

	    if (uProj.Display.Volume.Mute.Required && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (uProj.Display.Volume.Mute.Required <> uProj.Display.Volume.Mute.Actual) && iCommunicating) {
		iCommandBusy = true
		SetMute(uProj.Display.Volume.Mute.Required);
		wait 10 iCommandBusy = false
		iPollSequence = GET_MUTE;
		return
	    }

	    if (uProj.Display.PowerState.Required && (uProj.Display.PowerState.Required <> uProj.Display.PowerState.Actual) && (uProj.Display.PowerState.Actual <> ACTUAL_POWER_WARMING) && (uProj.Display.PowerState.Actual <> ACTUAL_POWER_COOLING) && iCommunicating) {
		iCommandBusy = true
		//iQueryLockOut = true
		SetPower(uProj.Display.PowerState.Required)
		wait 80 iCommandBusy = false
		iPollSequence = GET_POWER
		return
	    }

	    if (uProj.Display.Input.Required && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (uProj.Display.Input.Required <> uProj.Display.Input.Actual) && iCommunicating) {
		iCommandBusy = true
		SetInput(uProj.Display.Input.Required)
		wait 10 iCommandBusy = false
		iPollSequence = GET_INPUT
		return
	    }

	    if (iAutoAdjustRequired && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && iCommunicating) {
		SendString('KEY 4A')
		iAutoAdjustRequired = false
	    }

	    if ([vdvObject,VOL_UP] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (uProj.Display.Volume.Level.Actual < MAX_VOLUME) && iCommunicating) {
		SendString('VOL INC')
	    }

	    if ([vdvObject,VOL_DN] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (uProj.Display.Volume.Level.Actual > MIN_VOLUME) && iCommunicating) {
		SendString('VOL DEC')
	    }

	    if ((uProj.Display.Volume.Level.Required >= 0) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (uProj.Display.Volume.Level.Required <> uProj.Display.Volume.Level.Actual) && iCommunicating) {
		iCommandBusy = true
		SetVolume(uProj.Display.Volume.Level.Required);
		iPollSequence = GET_VOLUME;
		return
	    }

	    if ([vdvObject,44] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && iCommunicating) {
		SendString('KEY 03'); iCommandBusy = true; wait 5 iCommandBusy = false	//Menu
	    }

	    if ([vdvObject,45] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && iCommunicating) {
		SendString('KEY 35'); iCommandBusy = true; wait 5 iCommandBusy = false	//Up
	    }

	    if ([vdvObject,46] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && iCommunicating) {
		SendString('KEY 36'); iCommandBusy = true; wait 5 iCommandBusy = false	//Down
	    }

	    if ([vdvObject,47] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && iCommunicating) {
		SendString('KEY 37'); iCommandBusy = true; wait 5 iCommandBusy = false	//Left
	    }

	    if ([vdvObject,48] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && iCommunicating) {
		SendString('KEY 38'); iCommandBusy = true; wait 5 iCommandBusy = false	//Right
	    }

	    if ([vdvObject,49] && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && iCommunicating) {
		SendString('KEY 49'); iCommandBusy = true; wait 5 iCommandBusy = false	//Enter
	    }
	}
    }
}

define_function MaintainIPConnection() {
    if (!iIPConnected) {
	NAVClientSocketOpen(dvPort.port,cIPAddress,iTCPPort,IP_TCP)
    }
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort,cRxBuffer

    uProj.Display.Volume.Level.Required = -1
    uProj.Display.Volume.Level.Actual = -1
}
(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
data_event[dvPort] {
    online: {
	if (data.device.number <> 0) {
	    send_command data.device,"'SET BAUD 9600,N,8,1 485 DISABLE'"
	    send_command data.device,"'B9MOFF'"
	    send_command data.device,"'CHARD-0'"
	    send_command data.device,"'CHARDM-0'"
	    send_command data.device,"'HSOFF'"
	    timeline_create(TL_DRIVE,ltDrive,length_array(ltDrive),timeline_absolute,timeline_repeat)
	}

	if (data.device.number == 0) {
	    iIPConnected = true
	    timeline_create(TL_DRIVE,ltDrive,length_array(ltDrive),timeline_absolute,timeline_repeat)
	}
    }
    string: {
	    iCommunicating = true
	    iInitialized = true
	    TimeOut()
	    NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM, dvPort, data.text))
	    if (!iSemaphore) { Process() }
    }
    offline: {
	if (data.device.number == 0) {
	    NAVClientSocketClose(dvPort.port)
	    iIPConnected = false
	}
    }
    onerror: {
	if (data.device.number == 0) {

	}
    }
}

data_event[vdvObject] {
    online: {
	    NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_DESCRIPTION,Video Projector'")
	    NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_URL,www.epson.com'")
	    NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_NAME,EPSON'")
    }
    command: {
	stack_var char cCmdHeader[NAV_MAX_CHARS]
	stack_var char cCmdParam[2][NAV_MAX_CHARS]
	    NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))
	    cCmdHeader = DuetParseCmdHeader(data.text)
	    cCmdParam[1] = DuetParseCmdParam(data.text)
	    cCmdParam[2] = DuetParseCmdParam(data.text)
	    switch (cCmdHeader) {
		case 'PROPERTY': {
		    switch (cCmdParam[1]) {
			case 'IP_ADDRESS': {
			    cIPAddress = cCmdParam[2]
			}
			case 'TCP_PORT': {
			    iTCPPort = atoi(cCmdParam[2])
			    timeline_create(TL_IP_CHECK,ltIPCheck,length_array(ltIPCheck),timeline_absolute,timeline_repeat)
			}
		    }
		}
		case 'PASSTHRU': { SendString(cCmdParam[1]) }

		case 'POWER': {
		    switch (cCmdParam[1]) {
			case 'ON': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; Drive() }
			case 'OFF': { uProj.Display.PowerState.Required = REQUIRED_POWER_OFF; uProj.Display.Input.Required = 0; Drive() }
		    }
		}
		case 'ADJUST': { iAutoAdjustRequired = true; Drive() }
		case 'INPUT': {
		    switch (cCmdParam[1]) {
			case 'VGA': {
			    switch (cCmdParam[2]) {
				case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_VGA_1; Drive() }
				case '2': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_VGA_2; Drive() }
			    }
			}
			case 'RGB': {
			    switch (cCmdParam[2]) {
				case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_RGBHV_1; Drive() }
				case '2': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_RGBHV_2; Drive() }
			    }
			}
			case 'HDMI': {
			    switch (cCmdParam[2]) {
				case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_HDMI_1; Drive() }
			    }
			}
			case 'DVI': {
			    switch (cCmdParam[2]) {
				case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_DVI_1; Drive() }
			    }
			}
			case 'SDI': {
			    switch (cCmdParam[2]) {
				case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_SDI_1; Drive() }
			    }
			}
			case 'S-VIDEO': {
			    switch (cCmdParam[2]) {
				case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_SVIDEO_1; Drive() }
			    }
			}
			case 'HD_BASE_T': {
			    switch (cCmdParam[2]) {
				case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_HD_BASE_T; Drive() }
			    }
			}
			case 'COMPOSITE': {
			    switch (cCmdParam[2]) {
				case '1': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_VIDEO_1; Drive() }
				case '2': { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; uProj.Display.Input.Required = REQUIRED_INPUT_VIDEO_2; Drive() }
			    }
			}
		    }
		}
		case 'MUTE': {
		    NAVLog('RECEIVED MUTE COMMAND')
		    if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
		    NAVLog('RECEIVED MUTE COMMAND')
			switch (cCmdParam[1]) {
			    case 'ON': { uProj.Display.Volume.Mute.Required = REQUIRED_MUTE_ON; Drive() }
			    case 'OFF': { uProj.Display.Volume.Mute.Required = REQUIRED_MUTE_OFF; Drive() }
			}
		    }
		}
		case 'ASPECT': {
		    if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
			switch (cCmdParam[1]) {
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

channel_event[vdvObject,0] {
    on: {
	    switch (channel.channel) {
		case POWER: {
		    if (uProj.Display.PowerState.Required) {
			switch (uProj.Display.PowerState.Required) {
			    case REQUIRED_POWER_ON: { uProj.Display.PowerState.Required = REQUIRED_POWER_OFF; uProj.Display.Input.Required = 0; Drive() }
			    case REQUIRED_POWER_OFF: { uProj.Display.PowerState.Required = REQUIRED_POWER_ON; Drive() }
			}
		    }else {
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
			}else {
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

timeline_event[TL_IP_CHECK] { MaintainIPConnection() }

timeline_event[TL_NAV_FEEDBACK] {
	[vdvObject,DEVICE_COMMUNICATING]	= (iCommunicating)
	[vdvObject,DATA_INITIALIZED]	= (iInitialized)
	[vdvObject,VOL_MUTE_FB] = (uProj.Display.VideoMute.Actual == ACTUAL_MUTE_ON)
	[vdvObject,POWER_FB] = (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON)
	[vdvObject,LAMP_WARMING_FB]	= (uProj.Display.PowerState.Actual = ACTUAL_POWER_WARMING)
	[vdvObject,LAMP_COOLING_FB]	= (uProj.Display.PowerState.Actual = ACTUAL_POWER_COOLING)
	[vdvObject,31]	= ((uProj.Display.Input.Actual == ACTUAL_INPUT_VGA_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
	[vdvObject,32]	= ((uProj.Display.Input.Actual == ACTUAL_INPUT_VGA_2) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
	[vdvObject,33]	= ((uProj.Display.Input.Actual == ACTUAL_INPUT_RGBHV_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
	[vdvObject,34]	= ((uProj.Display.Input.Actual == ACTUAL_INPUT_RGBHV_2) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
	[vdvObject,35]	= ((uProj.Display.Input.Actual == ACTUAL_INPUT_HDMI_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
	[vdvObject,36]	= ((uProj.Display.Input.Actual == ACTUAL_INPUT_DVI_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
	[vdvObject,37]	= ((uProj.Display.Input.Actual == ACTUAL_INPUT_SVIDEO_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
	[vdvObject,38]	= ((uProj.Display.Input.Actual == ACTUAL_INPUT_VIDEO_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
	[vdvObject,39]	= ((uProj.Display.Input.Actual == ACTUAL_INPUT_HD_BASE_T) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
	[vdvObject,40]	= ((uProj.Display.Input.Actual == ACTUAL_INPUT_SDI_1) && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON))
}

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

