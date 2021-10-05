![Automation Resources Group](http://automationresourcesgroup.s3.amazonaws.com/ARGLogos/arg-logo-245.png)

#SafeRemote Library
The SafeRemote library provides an interface to commission / update safety systems. 

**NOTE**: SafeRemote only supports Safety Release 1.10 or later.

**NOTE**: If SafeRemote is connected to Safety Controller (SC) connection using SAFE DESIGNER's Remote Control is not allowed. 

##Initialization
In order to use SafeRemote a variable of type **SRWrap_typ** must be declared.	

	safeRemote.IN.CFG.SafeLogicID := 4; 		// The SafeLogic ID
	safeRemote.IN.CFG.FileDevice := 'safe'; 	// Enter File Device where safety program is located

**IN.CFG.UDID\_Low** and **IN.CFG.UDID\_High** will need to be mapped to the SC UDID\_Log and UDID\_High inputs respectively. If SC does not have the inputs available they can be accessed using *ASIOAcc*'s *AsIOAccRead* FUB.

	deviceName := 'IF6.ST1';
	channelNameLow := 'UDID_low';
	channelNameHigh := 'UDID_high';
	
	IOReadLow.pChannelName := ADR(channelNameLow);
	IOReadLow.pDeviceName := ADR(deviceName);
	IOReadLow.enable := TRUE;
	
	IOReadHigh.pChannelName := ADR(channelNameHigh);
	IOReadHigh.pDeviceName := ADR(deviceName);
	IOReadHigh.enable := TRUE;

	IF NOT (IOReadLow.value = 0) THEN
		safeRemote.IN.CFG.UDID_Low := IOReadLow.value;
		IOReadLow.enable := FALSE;
	END_IF
	
	IF NOT (IOReadHigh.value = 0) THEN
		safeRemote.IN.CFG.UDID_High := UDINT_TO_UINT(IOReadHigh.value);
		IOReadHigh.enable := FALSE;
	END_IF

	IOReadLow();
	IOReadHigh();

##Cyclic Operation

	SafeRemoteFn_Cyclic( safeRemote );

##SafeRemote Structure

###Inputs

####Commands
Commands are reset internally after each function call. 

- **LogIn** - Attempt log into SC using **Password** specified in parameters 
- **LogOut** - Log out of SC and stop communication.
- **SetPassword** - Sets SC password to **NewPassword** in parameters. If a password is already set **Password** is required. 
- **Transfer** - Starts transfer project transfer to SC.
- **Unlock** - Unlock SC to continue transfer. 
- **FormatSafeKey** - Performs a format on SC.
- **Scan** - Starts a system scan of SC.
- **ReadStatus** - Read status of SC.
- **AcknowledgeKey** - Attempt ACK of Safe Key change.
- **Acknowledge1Module** - Attempt ACK of 1 Module change.
- **Acknowledge2Module** - Attempt ACK of 2 Module changes.
- **Acknowledge3Module** - Attempt ACK of 3 Module changes.
- **AcknowledgeNModule** - Attempt ACK of N Modules changes.
- **AcknowledgeFirmware** - Attempt ACK of Firmware change.
- **AcknowledgeError** - Acknowledges FUB error.

####Parameters
- **Password** - SC password. Required when doing a **LogIn** or **SetPassword**.
- **NewPassword** - SC password to be set. Required when doing a **SetPassword**.
- **TransferMode** - Specifies whether to transfer application from **File** or **AppID**
- **AppID** - App ID # when performing a transfer in **SRWrap_Data_Object_Mode**.
- **File** - File name when performing a transfer in **SRWrap_File_Mode**.

####Configuration
- **SafeLogicID** - SafeLOGIC ID of safety controller.
- **UDID\_Low** - SC UDID_low (Set view io mapping or *ASIOAcc* library).
- **UDID\_High** - SC UDID_high (Set view io mapping or *ASIOAcc* library).
- **FileDevice** - File device for **File**.

###Outputs
- **ControlStatus** - SC status. Only valid when logged into SC. Refer to RemoteControlStatusTypeV2 in BR help.
- **StatusString** - FUB status string.
- **AckKeyNeeded** - Acknowledge of Safety Key is required.
- **AckModuleNeeded** - Acknowledge of Modules required.
- **AckNModuleNeeded** - Acknowledge of N number of Modules required.
- **NumAckModulesNeeded** - Number of Modules that have changed.
- **AckFirmwareNeeded** - Acknowledge of Safety Firmware is required.
- **PasswordSet** - SC password is set.
- **ConnectionStatus** - Connection Status. Refer to **SRWrap\_Connection\_Status\_enum**.
- **UnlockRequired** - Unlock required to continue.
- **Error** - FUB error occured.
- **ErrorID** - Current error ID.
- **ErrorString** - Current error text information.

##Error ID Numbers
- **0** - ERR\\_OK - No error
- **20605** - doERR\\_ILLOBJECT - Object NOT found
- **20609** - doERR\\_MODULNOTFOUND - Data object NOT found
- **20700** - fiERR\\_INVALID\\_PATH  - The specified path is invalid
- **20798** - fiERR\\_DEVICE\\_MANAGER - Error in device manager
- **36100** - safeERR\\_VERSION - Incorrect version OF command structure
- **36101** - safeERR\\_PW\_LENGTH - Incorrect password length
- **36102** - safeERR\_UDID - No UDID specified FOR safety controller
- **36103** - safeERR\_ALLOC\_MEM - Error allocating internal memory
- **36104** - safeERR\_INTERNAL\_ERROR - Internal error
- **36105** - safeERR\_TIMEOUT - Communication timeout
- **36106** - safeERR\_RC\_CMD - No command specified
- **36107** - safeERR\_RC\_ENTER\_DATA - Invalid command specified FOR Enter command
- **36108** - safeERR\_RC\_ENTER\_PW - No password specified FOR Enter command
- **36109** - safeERR\_RC\_ENTER\_SK\_PW - No new password specified FOR change
- **36110** - safeERR\_RC\_STATUS\_DATA - Invalid command FOR reading back status
- **36111** - safeERR\_RC\_DATA\_LENGTH - Incorrect data length FOR status information returned BY system
- **36112** - safeERR\_DL\_NO\_PASSWORD - No password specified FOR download
- **36113** - safeERR\_DL\_PROTOCOL - Incorrect protocol version OR header error
- **36114** - safeERR\_DL\_FILE\_OPEN - File already open
- **36115** - safeERR\_DL\_FILE\_INVALID - File invalid
- **36116** - safeERR\_DL\_FILE\_TOO\_BIG - File too large
- **36117** - safeERR\_DL\_WRITE - Write error
- **36118** - safeERR\_DL\_STREAM - Error at end OF stream
- **36119** - safeERR\_DL\_CHECKSUM - Incorrect checksum
- **36120** - safeERR\_DL\_UDID - Mismatch OF specified UDID with UDID OF safety controller
- **36121** - safeERR\_DL\_WRONG FILE\_SIZE - Incorrect file size
- **36122** - safeERR\_DL\_NO\_RIGHTS\_TO\_WRITE - No authorization TO write, incorrect password
- **36123** - safeERR\_DL\_UNLOCK\_FILE\_FILE - Error retrieving file information
- **36124** - safeERR\_DL\_UNLOCK\_READ - Read error
- **36125** - safeERR\_DL\_UNLOCK\_WRITE - Write error
- **36126** - safeERR\_DL\_STATIC\_UNLOCK - Constant signal TRUE on parameter in command structure
- **36127** - safeERR\_DL\_COMPARE\_FAILED - Comparison failed FOR read back data
- **36128** - safeERR\_DLDATA\_TYP\_ERR - Unknown OR invalid download type
- **36129** - safeERR\_DLDATA\_ERR\_DATA - Incorrect data specified FOR download
- **36130** - safeERR\_COT\_TYPE\_ERR - Unknown OR invalid upload type
- **36131** - safeERR\_COT\_READING\_FILE - Error reading from file
- **36132** - safeERR\_BUFFER\_NULL - Required input buffer is NULL
- **36133** - safeERR\_BUFFER\_TOO\_SMALL - Required input buffer too small
- **36134** - safeERR\_FILE\_EMPTY - File empty OR NOT found on safety controller
- **36135** - safeERR\_FI\_TYPE\_ERR - Error retrieving file information
- **36136** - safeERR\_SLINFO\_TYPE\_ERR - Unknown OR invalid SafeLOGIC information
- **36137** - safeERR\_SLINFO\_RET\_ERR - Remote control command returning error
- **36138** - safeERR\_COT\_PWD\_ERR - Invalid password
- **36180** - safeERR\_TC\_INV\_TABTYPE - Table type NOT supported
- **36181** - safeERR\_TC\_INV\_INST - Invalid table instance
- **36182** - Invalid pointer - Null pointer specified
- **36183** - safeERR\_TC\_INV\_TAB\_LEN - Number OF table entries is 0 OR unable TO determine table length (e.g. table type NOT supported)
- **36184** - safeERR\_TC\_INV\_USER - Username longer than 47 bytes plus string terminator
- **36185** - safeERR\_TC\_TYPE\_CPY\_FCT - Table type dependent copy FUNCTION returning error
- **36186** - safeERR\_TC\_CHECK\_FAILED - Type-dependent table check failed
- **36187** - safeERR\_TC\_EXTRACT\_FAILED - Unable TO export HMI application data from the generated raw table data
- **36188** - safeERR\_TC\_LOCK\_FAILED - Tables CRC protection returned error
- **36189** - safeERR\_TC\_ACK\_SET - Input "AckData" was set although this is NOT permitted
- **36190** - safeERR\_TC\_INVALID\_STEP - The step switching mechanism OF the FUNCTION block is in an invalid step
- **36191** - safeWRN\_TC\_WAIT\_FOR\_ACK - The FUNCTION block is waiting FOR HMI application data TO be acknowledged
- **65535** - ERR\_FUB\_BUSY - FUNCTION block still working