(*
 * File: Types.typ
 * Copyright (c) 2023 Loupe
 * https://loupe.team
 * 
 * This file is part of SafeRemote, licensed under the MIT License.
 *)

TYPE
	SRWrap_Internal_typ : 	STRUCT 
		continousStatus : BOOL;
		State : SRWrap_ST_enum;
		SafeDownload : safeDownloadApplication_V2;
		SafeRemoteControl : safeRemoteControl_V2;
		SafeDownloadCmd : DownloadCmdApplicationTypeV1;
		SafeRemoteCmd : RemoteControlCmdTypeV1;
		SafeInfoPwdInfo : InfoCmdPwdInfoTypeV1;
		SafeInfoPwdChk : InfoCmdPwdChkTypeV1;
		SafeInfo : safeLogicInfo;
		password : STRING[16];
		timeOut : TON;
	END_STRUCT;
	SRWrap_OUT_typ : 	STRUCT 
		ControlStatus : RemoteControlStatusTypeV2; (*Control Status from Safety Controller*)
		StatusString : STRING[80]; (*Status Description*)
		AckKeyNeeded : BOOL; (*Acknowledge of Safe Key Exchange needed*)
		AckModuleNeeded : BOOL; (*Acknowledge of Module Change needed*)
		AckNModuleNeeded : BOOL; (*Acknowledge of N number of Modules needed*)
		AckFirmwareNeeded : BOOL; (*Acknowledge of Firmware Change needed*)
		NumAckModulesNeeded : UINT; (*Number of Modules Missing OR with different UDID*)
		PasswordSet : BOOL; (*Password is set on controller*)
		ConnectionStatus : USINT; (*0: Not connected, 1: Connection Not logged in, 2: Logged In*)
		UnlockRequired : BOOL; (*Waiting on Unlock*)
		Error : BOOL; (*Error Present when TRUE*)
		ErrorID : UINT; (*Error ID*)
		ErrorString : STRING[320]; (*Error Description*)
	END_STRUCT;
	SRWrap_IN_CMD_typ : 	STRUCT 
		AcknowledgeError : BOOL; (*Ack FUB errors*)
		LogIn : BOOL; (*Attempts to connect and logIn to Safe Controller*)
		Unlock : USINT; (*Unlock Safe Controller for download (Do not hold high) (1: Unlock, 2: Cancel)*)
		AcknowledgeKey : BOOL; (*Acknowledge Safe Key change / no change*)
		Acknowledge1Module : BOOL; (*Acknowledge Number of Module changes*)
		Acknowledge2Module : BOOL; (*Acknowledge Number of Module changes*)
		Acknowledge3Module : BOOL; (*Acknowledge Number of Module changes*)
		Acknowledge4Module : BOOL; (*Acknowledge Number of Module changes*)
		AcknowledgeNModule : BOOL; (*Acknowledge Number of Module changes*)
		AcknowledgeFirmware : BOOL; (*Acknowledge Firmware change / no change*)
		Transfer : BOOL; (*Download new Safe Application*)
		SetPassword : BOOL; (*Set / Change Password*)
		FormatSafeKey : BOOL; (*Format Safety Controller*)
		ReadStatus : BOOL; (*Read Control Status from Safety Controller*)
		Scan : BOOL; (*Starts a system scan*)
		LogOut : BOOL; (*Disconnect from Safety Controller*)
	END_STRUCT;
	SRWrap_IN_PAR_typ : 	STRUCT 
		Password : STRING[16]; (*Safety Controller Password*)
		NewPassword : STRING[16]; (*Password to be Set*)
		TransferMode : SRWrap_Transfer_Mode_enum; (*Enables transfer from file*)
		AppID : UINT; (*ID of Safe Application (used if FromFile is disabled)*)
		File : STRING[80]; (*File to be transfered to safety controller (located in CFG.FileDevice)(used if FromFile is enabled)*)
	END_STRUCT;
	SRWrap_IN_CFG_typ : 	STRUCT 
		SafeLogicID : UINT; (*SafeLOGIC ID of the safety controller*)
		UDID_Low : {REDUND_UNREPLICABLE} UDINT; (*Safe Controller UDID_low (Set via iomapping or ASIOAcc)*)
		UDID_High : UINT; (*Safe Controller UDID_high (Set via iomapping or ASIOAcc)*)
		FileDevice : STRING[80]; (*Location of PAR.File when tranfering to Safety Controller*)
	END_STRUCT;
	SRWrap_IN_typ : 	STRUCT 
		CMD : SRWrap_IN_CMD_typ;
		PAR : SRWrap_IN_PAR_typ;
		CFG : SRWrap_IN_CFG_typ;
	END_STRUCT;
	SRWrap_typ : 	STRUCT 
		IN : SRWrap_IN_typ;
		OUT : SRWrap_OUT_typ;
		Internal : SRWrap_Internal_typ;
	END_STRUCT;
	SRWrap_ST_enum : 
		(
		SRWrap_ST_DISABLED,
		SRWrap_ST_CHECKING_CONNECTION,
		SRWrap_ST_CHECKING_PASSWORD,
		SRWrap_ST_COMPARING_PASSWORD,
		SRWrap_ST_IDLE,
		SpWrap_ST_SET_PASSWORD,
		SRWrap_ST_SETTING_PASSWORD,
		SRWrap_ST_FORMATTING_SAFEKEY,
		SRWrap_ST_LOGGEDIN,
		SRWrap_ST_DOWNLOADING,
		SRWrap_ST_RESTARTING,
		SRWrap_ST_ACK_KEY,
		SRWrap_ST_ACKING_KEY,
		SRWrap_ST_ACK_MODULE,
		SRWrap_ST_ACKING_MODULE,
		SRWrap_ST_ACK_FIRMWARE,
		SRWrap_ST_ACKING_FIRMWARE,
		SRWrap_ST_SCANNING,
		SRWrap_ST_GETSTATUS,
		SRWrap_ST_ERROR
		);
	SRWrap_Connection_Status_enum : 
		(
		SRWrap_No_Connection := 0, (*No connection to Safe Controller*)
		SRWrap_Connection := 1, (*Connection found to Safe Controller*)
		SRWrap_Logged_In := 2 (*Connection found to Safe Controller and successfully logged in *)
		);
	SRWrap_Transfer_Mode_enum : 
		(
		SRWrap_Data_Object_Mode := 0, (*Tranfer Safety Application from Application on PLC*)
		SRWrap_File_Mode := 1 (*Tranfer Safety Application from File on PLC*)
		);
END_TYPE
