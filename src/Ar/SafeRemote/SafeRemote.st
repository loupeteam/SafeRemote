(*
 * File: SafeRemote.st
 * Copyright (c) 2023 Loupe
 * https://loupe.team
 * 
 * This file is part of SafeRemote, licensed under the MIT License.
 *
 *)

 (********************************************************************
 * Implementation OF library SafeRemote
 ********************************************************************) 


(********************************************************************)
(* This function manages commissioning of a Safty Controller Program*)
(********************************************************************)

(* Usage:
 *
 *  *)

(*  TODO:
 *	Handle outputs for disabled state (Probably need to reset status struct)
 *	Manage user giving app id and file name
 *	Timeouts (I think this is fine for now)
 *)

FUNCTION SafeRemoteFn_Cyclic
	
	t.Internal.continousStatus := FALSE;
	t.OUT.StatusString := '';
	t.OUT.UnlockRequired := FALSE;
	
	IF t.IN.CMD.LogOut THEN
		t.Internal.State := SRWrap_ST_DISABLED;
	END_IF
	
	CASE t.Internal.State OF
		SRWrap_ST_DISABLED:
			//Reset Everything if possible
			t.OUT.Error := FALSE;
			t.OUT.ErrorID := 0;
			t.OUT.ErrorString := '';
			
			t.OUT.ConnectionStatus := 0;
			t.OUT.StatusString := 'Logged Out';
			
			IF t.IN.CMD.LogIn THEN
				t.Internal.State := SRWrap_ST_CHECKING_CONNECTION;
				t.Internal.password := t.IN.PAR.Password;
				t.IN.PAR.Password := '';
			END_IF
		
		SRWrap_ST_CHECKING_CONNECTION:
			t.OUT.StatusString := 'Connecting...';
			t.OUT.ConnectionStatus := 0;
			
			IF t.Internal.SafeRemoteControl.Done AND t.Internal.SafeRemoteControl.SafeLOGICStatus.Number = UDINT_TO_UINT(t.Internal.State) THEN
				t.OUT.ConnectionStatus := 1;
				
				IF t.Internal.SafeRemoteControl.SafeLOGICStatus.SafeOSState <> 16#33 THEN
					//Move on
					t.Internal.State := SRWrap_ST_CHECKING_PASSWORD;
				ELSE
					t.OUT.ConnectionStatus := 0;
					//No connection
					t.Internal.State := SRWrap_ST_DISABLED;
					t.OUT.StatusString := 'Connection Failed'; 
				END_IF
			ELSIF t.Internal.SafeRemoteControl.Error THEN 
				IF t.Internal.SafeRemoteCmd.Number = UDINT_TO_UINT(t.Internal.State) THEN
					IF t.Internal.SafeRemoteControl.StatusID = safeERR_RC_ENTER_PW THEN
						//Incorrect Password
						//This will only occur on V1.10 and newer
						t.OUT.StatusString := 'Failed to Connect: Incorrect Password';
						t.Internal.State := SRWrap_ST_IDLE;
					ELSIF t.Internal.SafeRemoteControl.StatusID = safeERR_TIMEOUT THEN
						t.OUT.StatusString := 'Failed to Connect';
						t.Internal.State := SRWrap_ST_DISABLED;
					ELSE
						t.Internal.State := SRWrap_ST_ERROR;
						t.OUT.ErrorID := t.Internal.SafeRemoteControl.StatusID;
						SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);
					END_IF
				END_IF
			ELSIF NOT t.Internal.SafeRemoteControl.Busy THEN
				//Check connection to Safty Controller
				t.Internal.SafeRemoteCmd.Number := UDINT_TO_UINT(t.Internal.State); //Set command number
				t.Internal.SafeRemoteCmd.Command := safeCMD_STATUS;
				t.Internal.SafeRemoteCmd.Data := 0;
				t.Internal.SafeRemoteCmd.Password := t.Internal.password;
				t.Internal.SafeRemoteCmd.Version := safeVERSION_R107; //Function block requires R107 for v1.07 or higher
				t.Internal.SafeRemoteControl.SafeLOGICID := t.IN.CFG.SafeLogicID;
				t.Internal.SafeRemoteControl.pCommandData := ADR(t.Internal.SafeRemoteCmd);
				t.Internal.SafeRemoteControl.Execute := TRUE;
			END_IF
					
		SRWrap_ST_CHECKING_PASSWORD:		
			t.OUT.StatusString := 'Checking Password';
			IF NOT t.Internal.SafeRemoteControl.Busy THEN
				IF t.Internal.SafeInfo.Done THEN
					IF t.Internal.SafeInfoPwdInfo.PasswordSet THEN // Password is set
						t.Internal.State := SRWrap_ST_COMPARING_PASSWORD; 
						t.OUT.PasswordSet := TRUE;
					ELSE // Password not set
						t.Internal.State := SRWrap_ST_IDLE;
						t.OUT.PasswordSet := FALSE;
					END_IF
				ELSIF t.Internal.SafeInfo.Error THEN
					t.Internal.State := SRWrap_ST_ERROR;
					t.OUT.ErrorID:= t.Internal.SafeInfo.StatusID;
					t.OUT.ErrorString := 'Checking Password: ';
					SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);
				ELSIF NOT t.Internal.SafeInfo.Busy THEN
					//Check if Safty Controller has a password
					t.Internal.SafeInfoPwdInfo.Version := safeVERSION_R110; // Function block required R110 for v1.10 or higher
			
					t.Internal.SafeInfo.Type := safeINFO_TYPE_PWD_INFO;
					t.Internal.SafeInfo.SafeLOGICID := t.IN.CFG.SafeLogicID;
					t.Internal.SafeInfo.pCommandData := ADR(t.Internal.SafeInfoPwdInfo);
					t.Internal.SafeInfo.Execute := TRUE;
				END_IF
			END_IF
				
		SRWrap_ST_COMPARING_PASSWORD:
			t.OUT.StatusString := 'Checking Password';
			IF NOT t.Internal.SafeRemoteControl.Busy THEN
				IF t.Internal.SafeInfo.Done THEN
					IF t.Internal.SafeInfoPwdChk.PasswordEqual THEN
						// Correct Password
						t.Internal.State := SRWrap_ST_LOGGEDIN;
					ELSE
						// Incorrect Password
						t.Internal.State := SRWrap_ST_IDLE;
						t.OUT.StatusString := 'Incorrect Password';
					END_IF
				ELSIF t.Internal.SafeInfo.Error THEN
					t.Internal.State := SRWrap_ST_ERROR;
					t.OUT.ErrorString := 'Comparing Passwords: ';
					SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);
				ELSIF NOT t.Internal.SafeInfo.Busy THEN				
					//Check Password against Safty Controller
					t.Internal.SafeInfoPwdChk.Password := t.Internal.password;
					t.Internal.SafeInfoPwdChk.Version := safeVERSION_R110;
			
					t.Internal.SafeInfo.Type := safeINFO_TYPE_PWD_CHK;
					t.Internal.SafeInfo.SafeLOGICID := t.IN.CFG.SafeLogicID;
					t.Internal.SafeInfo.pCommandData := ADR(t.Internal.SafeInfoPwdChk);
					t.Internal.SafeInfo.Execute := TRUE;
				END_IF	
			END_IF
		
		SRWrap_ST_IDLE:
			t.OUT.ConnectionStatus := 1;
			t.OUT.StatusString := 'Connected. Need to log in';
			
			t.Internal.continousStatus := TRUE;

			IF t.IN.CMD.SetPassword THEN
				t.Internal.State := SRWrap_ST_SETTING_PASSWORD;
//				t.Internal.password := t.IN.PAR.Password;
//				t.IN.PAR.Password := '';
			ELSIF t.IN.CMD.FormatSafeKey THEN
				t.Internal.State := SRWrap_ST_FORMATTING_SAFEKEY;
			ELSIF t.IN.CMD.LogIn THEN
				t.Internal.State := SRWrap_ST_CHECKING_PASSWORD;
				t.Internal.password := t.IN.PAR.Password;
				t.IN.PAR.Password := '';
			ELSIF t.IN.CMD.Scan THEN
				t.Internal.State := SRWrap_ST_SCANNING;
			END_IF
		
		SRWrap_ST_SETTING_PASSWORD:	
			t.OUT.StatusString := 'Setting Password';
			//Set Safty Controller password
			IF t.Internal.SafeRemoteControl.Done AND t.Internal.SafeRemoteControl.SafeLOGICStatus.Number = UDINT_TO_UINT(t.Internal.State) THEN
				//Password Set
				t.Internal.State := SRWrap_ST_CHECKING_PASSWORD; //Check if valid
			ELSIF t.Internal.SafeRemoteControl.Error THEN
				IF t.Internal.SafeRemoteCmd.Number = UDINT_TO_UINT(t.Internal.State) THEN
					IF t.Internal.SafeRemoteControl.StatusID = 36108 THEN // Invalid Password
						// Provide a more specific error than what is givin in help
						t.Internal.State := SRWrap_ST_ERROR;
						t.OUT.ErrorID := t.Internal.SafeRemoteControl.StatusID;
						t.OUT.ErrorString := 'Setting Password: Incorrect Password';
					ELSE
						t.Internal.State := SRWrap_ST_ERROR;
						t.OUT.ErrorID := t.Internal.SafeRemoteControl.StatusID;
						t.OUT.ErrorString := 'Setting Password: ';
						SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);	
					END_IF
				END_IF
			ELSIF NOT t.Internal.SafeRemoteControl.Busy THEN
				// Passwords are required to be 6 - 16 chars long
				// Shorter than 6 is vaild but will not allow logins using BR's remote control
				IF brsstrlen(ADR(t.IN.PAR.NewPassword)) > 6 THEN
					t.Internal.SafeRemoteCmd.Number := UDINT_TO_UINT(t.Internal.State); //Set command number
					t.Internal.SafeRemoteCmd.Command := safeCMD_ENTER;
					t.Internal.SafeRemoteCmd.NewPassword := t.IN.PAR.NewPassword;
					t.Internal.SafeRemoteCmd.Password := t.IN.PAR.Password;
					t.Internal.SafeRemoteCmd.Data := safeCMD_SK_PW;
					t.Internal.SafeRemoteCmd.Version := safeVERSION_R107;
			
					t.Internal.SafeRemoteControl.SafeLOGICID := t.IN.CFG.SafeLogicID;
					t.Internal.SafeRemoteControl.pCommandData := ADR(t.Internal.SafeRemoteCmd);
					t.Internal.SafeRemoteControl.Execute := TRUE;
				
					t.Internal.password := t.IN.PAR.NewPassword;
					t.IN.PAR.Password := '';
					t.IN.PAR.NewPassword := '';
				ELSE
					t.Internal.State := SRWrap_ST_ERROR;
					t.OUT.ErrorID := t.Internal.SafeRemoteControl.StatusID;
					t.OUT.ErrorString := 'Setting Password: New Password must be between 6 - 16 chars';
				END_IF
			END_IF
		
		SRWrap_ST_FORMATTING_SAFEKEY:
			t.OUT.StatusString := 'Formatting Safe Key';
			
			//Format Safe key
			IF t.Internal.SafeRemoteControl.Done AND t.Internal.SafeRemoteControl.SafeLOGICStatus.Number = UDINT_TO_UINT(t.Internal.State) THEN
				t.Internal.State := SRWrap_ST_IDLE;
			ELSIF t.Internal.SafeRemoteControl.Error THEN
				IF t.Internal.SafeRemoteControl.SafeLOGICStatus.Number = UDINT_TO_UINT(t.Internal.State) THEN
					t.Internal.State := SRWrap_ST_ERROR;
					t.OUT.ErrorID := t.Internal.SafeRemoteControl.StatusID;
					t.OUT.ErrorString := 'Formatting: ';
					SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);
				END_IF
			ELSIF NOT t.Internal.SafeRemoteControl.Busy THEN
				t.Internal.SafeRemoteCmd.Number := UDINT_TO_UINT(t.Internal.State); //Set command number
				t.Internal.SafeRemoteCmd.Command := safeCMD_ENTER;
				t.Internal.SafeRemoteCmd.Data := safeCMD_SK_FORMAT;
				t.Internal.SafeRemoteCmd.Password := t.Internal.password;
				t.Internal.SafeRemoteCmd.Version := safeVERSION_R107;
				
				t.Internal.SafeRemoteControl.Execute := TRUE;
				t.Internal.SafeRemoteControl.pCommandData := ADR(t.Internal.SafeRemoteCmd);
				t.Internal.SafeRemoteControl.SafeLOGICID := t.IN.CFG.SafeLogicID;
			END_IF
		
		SRWrap_ST_LOGGEDIN:
			//Reset Everything if possible
			t.OUT.ConnectionStatus := 2;
			t.OUT.StatusString := 'Logged In';
			
			t.Internal.continousStatus := TRUE;
			
			//Check if password is incorrect
			IF t.Internal.SafeRemoteControl.StatusID = safeERR_RC_ENTER_PW THEN 
				t.Internal.State := SRWrap_ST_IDLE;
			
			//Else Wait for user input
			ELSIF t.IN.CMD.SetPassword THEN
				t.Internal.State := SRWrap_ST_SETTING_PASSWORD;
//				t.Internal.password := t.IN.PAR.Password;
//				t.IN.PAR.Password := '';
			ELSIF t.IN.CMD.Transfer THEN
				t.Internal.State := SRWrap_ST_DOWNLOADING;
			ELSIF t.IN.CMD.FormatSafeKey THEN
				t.Internal.State := SRWrap_ST_FORMATTING_SAFEKEY;
			ELSIF t.IN.CMD.ReadStatus THEN
				t.Internal.State := SRWrap_ST_GETSTATUS;
			ELSIF t.IN.CMD.AcknowledgeKey THEN
				t.Internal.State := SRWrap_ST_ACKING_KEY;
			ELSIF t.IN.CMD.Acknowledge1Module THEN
				t.Internal.SafeRemoteCmd.Data := safeCMD_1_UDID_ACKN;
				t.Internal.State := SRWrap_ST_ACKING_MODULE;
			ELSIF t.IN.CMD.Acknowledge2Module THEN
				t.Internal.State := SRWrap_ST_ACKING_MODULE;
				t.Internal.SafeRemoteCmd.Data := safeCMD_2_UDID_ACKN;
			ELSIF t.IN.CMD.Acknowledge3Module THEN
				t.Internal.State := SRWrap_ST_ACKING_MODULE;
				t.Internal.SafeRemoteCmd.Data := safeCMD_3_UDID_ACKN;
			ELSIF t.IN.CMD.Acknowledge4Module THEN
				t.Internal.State := SRWrap_ST_ACKING_MODULE;
				t.Internal.SafeRemoteCmd.Data := safeCMD_4_UDID_ACKN;
			ELSIF t.IN.CMD.AcknowledgeNModule THEN
				t.Internal.State := SRWrap_ST_ACKING_MODULE;
				t.Internal.SafeRemoteCmd.Data := safeCMD_N_UDID_ACKN;
			ELSIF t.IN.CMD.AcknowledgeFirmware THEN
				t.Internal.State := SRWrap_ST_ACKING_FIRMWARE;
			ELSIF t.IN.CMD.Scan THEN
				t.Internal.State := SRWrap_ST_SCANNING;
			END_IF
		
		SRWrap_ST_DOWNLOADING:	
			t.OUT.StatusString := 'Transferring Application';
			t.OUT.UnlockRequired := t.Internal.SafeDownload.UnlockRequired;
			
			IF NOT t.Internal.SafeRemoteControl.Busy THEN //Wait fo safeRemote to stop talking to the Safe controller
				//Download Safty Application to Safty Controller
				IF t.IN.PAR.TransferMode = SRWrap_Data_Object_Mode THEN
					t.Internal.SafeDownloadCmd.ApplicationID := t.IN.PAR.AppID; // Safe application id (if 0 use device and file)	
				ELSE
					t.Internal.SafeDownloadCmd.ApplicationID := 0; // Safe application id (if 0 use device and file)
				END_IF
				
				t.Internal.SafeDownloadCmd.Device := t.IN.CFG.FileDevice; // File Device of Safe application
				t.Internal.SafeDownloadCmd.File := t.IN.PAR.File; // File Name of Safe application
				t.Internal.SafeDownloadCmd.Password := t.Internal.password;
				t.Internal.SafeDownloadCmd.Version := safeVERSION_R107;
				t.Internal.SafeDownloadCmd.Unlock := t.IN.CMD.Unlock;
				t.Internal.SafeDownloadCmd.UDID_High := t.IN.CFG.UDID_High; // Set via iomapping or ASIOAcc
				t.Internal.SafeDownloadCmd.UDID_Low := t.IN.CFG.UDID_Low; // Set via iomapping or ASIOAcc
				
				t.Internal.SafeDownload.SafeLOGICID := t.IN.CFG.SafeLogicID;
				t.Internal.SafeDownload.pCommandData := ADR(t.Internal.SafeDownloadCmd);
				t.Internal.SafeDownload.Execute := TRUE;
				
				IF t.Internal.SafeDownload.Done THEN
					t.Internal.State := SRWrap_ST_RESTARTING;
				ELSIF t.Internal.SafeDownload.UnlockRequired THEN
					//User needs to unlock
					t.OUT.StatusString := 'Unlock required';
					
					//NOTE: unlock requests must be handled by authorized personnel only. Automated acknowledgment and unlocking logic is not permitted.
				ELSIF t.Internal.SafeDownload.Error THEN
					t.Internal.State := SRWrap_ST_ERROR;
					t.OUT.ErrorID := t.Internal.SafeDownload.StatusID;
					t.OUT.ErrorString := 'Transfer: ';
					SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);
				END_IF
			END_IF
		
		SRWrap_ST_RESTARTING:// Add error handling in the future!!!	
			t.OUT.StatusString := 'Safety Controller Restarting';
			
			//Restart Saftly Controller
			IF t.Internal.SafeRemoteControl.Done AND 
				t.Internal.SafeRemoteControl.StatusID = ERR_OK AND 
				t.Internal.SafeRemoteControl.SafeLOGICStatus.State = 0 AND
				t.Internal.SafeRemoteControl.SafeLOGICStatus.Number = UDINT_TO_UINT(t.Internal.State) THEN
				
				// Restart successful 
				t.Internal.State := SRWrap_ST_LOGGEDIN;
				//memcpy(ADR(t.Internal.ControlStatus), ADR(t.Internal.SafeRemoteControl.SafeLOGICStatus), SIZEOF(t.Internal.ControlStatus));
			ELSIF t.Internal.SafeRemoteControl.Error THEN 
				IF t.Internal.SafeRemoteCmd.Number = UDINT_TO_UINT(t.Internal.State) THEN
					// Some errors are acceptable in this state
					IF NOT (t.Internal.SafeRemoteControl.StatusID = safeERR_TIMEOUT) THEN
						t.OUT.ErrorID := t.Internal.SafeRemoteControl.StatusID;
						t.OUT.ErrorString := 'Restart: ';
						SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);
						t.Internal.State := SRWrap_ST_ERROR;
					END_IF
				END_IF
			ELSIF t.Internal.timeOut.Q THEN
				t.OUT.ErrorString := 'Restart Timeout';
				t.Internal.State := SRWrap_ST_ERROR;
			ELSIF NOT t.Internal.SafeRemoteControl.Busy THEN
				t.Internal.SafeRemoteCmd.Number := UDINT_TO_UINT(t.Internal.State); //Set command number
				t.Internal.SafeRemoteCmd.Command := safeCMD_STATUS;
				t.Internal.SafeRemoteCmd.Data := 0;
				t.Internal.SafeRemoteCmd.Password := t.Internal.password;
				t.Internal.SafeRemoteCmd.Version := safeVERSION_R107;

				t.Internal.SafeRemoteControl.SafeLOGICID := t.IN.CFG.SafeLogicID;
				t.Internal.SafeRemoteControl.pCommandData := ADR(t.Internal.SafeRemoteCmd);
				t.Internal.SafeRemoteControl.Execute := TRUE;
				
				t.Internal.timeOut.PT := t#90s;
			ELSE
				t.Internal.timeOut.IN := TRUE;
			END_IF	
		
		SRWrap_ST_ACKING_KEY:
			//Ack SAFE Key
			t.OUT.StatusString := 'Acknowledging Safe Key';
			
			//Wait for till acknowledged
			IF t.Internal.SafeRemoteControl.Done AND t.Internal.SafeRemoteControl.SafeLOGICStatus.Number = UDINT_TO_UINT(t.Internal.State) THEN
				t.Internal.State := SRWrap_ST_LOGGEDIN;
				
				// Set Ack Key needed to false until next scan
				t.OUT.AckKeyNeeded := 0;
			ELSIF t.Internal.SafeRemoteControl.Error THEN 
				IF t.Internal.SafeRemoteCmd.Number = UDINT_TO_UINT(t.Internal.State) THEN
					t.Internal.State := SRWrap_ST_ERROR;
					t.OUT.ErrorID := t.Internal.SafeRemoteControl.StatusID;
					t.OUT.ErrorString := 'Acknowledging Key: ';
					SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);
				END_IF
			ELSIF NOT t.Internal.SafeRemoteControl.Busy THEN 
				t.Internal.SafeRemoteCmd.Number := UDINT_TO_UINT(t.Internal.State); //Set command number
				t.Internal.SafeRemoteCmd.Command := safeCMD_ENTER;
				t.Internal.SafeRemoteCmd.Data := safeCMD_SK_XCHG;
				t.Internal.SafeRemoteCmd.Password := t.Internal.password;
				t.Internal.SafeRemoteCmd.Version := safeVERSION_R107;
		
				t.Internal.SafeRemoteControl.Execute := TRUE;
				t.Internal.SafeRemoteControl.pCommandData := ADR(t.Internal.SafeRemoteCmd);
				t.Internal.SafeRemoteControl.SafeLOGICID := t.IN.CFG.SafeLogicID;
			END_IF
		
		SRWrap_ST_ACKING_MODULE:
			//Ack Safe Modules 
			t.OUT.StatusString := 'Acknowledging Missing Modules';
			
			// Wait for acknowledged
			IF t.Internal.SafeRemoteControl.Done AND t.Internal.SafeRemoteControl.SafeLOGICStatus.Number = UDINT_TO_UINT(t.Internal.State) THEN
				t.Internal.State := SRWrap_ST_LOGGEDIN;
				
				// Set Ack modules needed to false until next scan
				t.OUT.AckNModuleNeeded := 0;
				t.OUT.AckModuleNeeded := 0;
			ELSIF t.Internal.SafeRemoteControl.Error THEN
				IF t.Internal.SafeRemoteCmd.Number = UDINT_TO_UINT(t.Internal.State) THEN
					t.Internal.State := SRWrap_ST_ERROR;
					t.OUT.ErrorID := t.Internal.SafeRemoteControl.StatusID;
					t.OUT.ErrorString := 'Acknowledging Module: ';
					SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);
				END_IF
			ELSIF NOT t.Internal.SafeRemoteControl.Busy THEN
				t.Internal.SafeRemoteCmd.Number := UDINT_TO_UINT(t.Internal.State); //Set command number
				t.Internal.SafeRemoteCmd.Command := safeCMD_ENTER;
				t.Internal.SafeRemoteCmd.Version := safeVERSION_R107;
			
				t.Internal.SafeRemoteControl.Execute := TRUE;
				t.Internal.SafeRemoteControl.pCommandData := ADR(t.Internal.SafeRemoteCmd);
				t.Internal.SafeRemoteControl.SafeLOGICID := t.IN.CFG.SafeLogicID;
			
			END_IF
		// Add error handling...(if user enters wrong # of modules
		
		SRWrap_ST_ACKING_FIRMWARE:
			//Ack Safe Firmware
			t.Internal.SafeRemoteCmd.Command := safeCMD_ENTER;
			t.OUT.StatusString := 'Acknowledging Firmware';

			// Wait for acknowledge
			IF t.Internal.SafeRemoteControl.Done AND t.Internal.SafeRemoteControl.SafeLOGICStatus.Number = UDINT_TO_UINT(t.Internal.State) THEN
				t.Internal.State := SRWrap_ST_LOGGEDIN;
				
				// Set Firmware Ack needed false unitl next scan
				t.OUT.AckFirmwareNeeded := 0;
			ELSIF t.Internal.SafeRemoteControl.Error THEN
				IF t.Internal.SafeRemoteCmd.Number = UDINT_TO_UINT(t.Internal.State) THEN
					t.Internal.State := SRWrap_ST_ERROR;
					t.OUT.ErrorID := t.Internal.SafeRemoteControl.StatusID;
					t.OUT.ErrorString := 'Acknowledging Firmware: ';
					SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);
				END_IF
			ELSIF NOT t.Internal.SafeRemoteControl.Busy THEN
				t.Internal.SafeRemoteCmd.Number := UDINT_TO_UINT(t.Internal.State); //Set command number
				t.Internal.SafeRemoteCmd.Data := safeCMD_FW_ACKN;
				t.Internal.SafeRemoteCmd.Password := t.Internal.password;
				t.Internal.SafeRemoteCmd.Version := safeVERSION_R107;
			
				t.Internal.SafeRemoteControl.Execute := TRUE;
				t.Internal.SafeRemoteControl.pCommandData := ADR(t.Internal.SafeRemoteCmd);
				t.Internal.SafeRemoteControl.SafeLOGICID := t.IN.CFG.SafeLogicID;
			END_IF
		
		SRWrap_ST_SCANNING:
			t.OUT.StatusString := 'Scanning';
			
			//Format Safe key
			IF t.Internal.SafeRemoteControl.Done AND t.Internal.SafeRemoteControl.SafeLOGICStatus.Number = UDINT_TO_UINT(t.Internal.State) THEN
				// Go back to previous idle state 
				IF t.OUT.ConnectionStatus = 2 THEN
					t.Internal.State := SRWrap_ST_LOGGEDIN;
				ELSIF t.OUT.ConnectionStatus = 1 THEN
					t.Internal.State := SRWrap_ST_IDLE;
				ELSE
					t.Internal.State := SRWrap_ST_DISABLED;
				END_IF
			ELSIF t.Internal.SafeRemoteControl.Error THEN 
				IF t.Internal.SafeRemoteCmd.Number = UDINT_TO_UINT(t.Internal.State) THEN
					t.Internal.State := SRWrap_ST_ERROR;
					t.OUT.ErrorID := t.Internal.SafeRemoteControl.StatusID;
					t.OUT.ErrorString := 'Scanning: ';
					SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);
				END_IF
			ELSIF NOT t.Internal.SafeRemoteControl.Busy THEN
				t.Internal.SafeRemoteCmd.Number := UDINT_TO_UINT(t.Internal.State); //Set command number
				t.Internal.SafeRemoteCmd.Command := safeCMD_ENTER;
				t.Internal.SafeRemoteCmd.Data := safeCMD_SCAN;
				t.Internal.SafeRemoteCmd.Password := t.Internal.password;
				t.Internal.SafeRemoteCmd.Version := safeVERSION_R107;
				
				t.Internal.SafeRemoteControl.Execute := TRUE;
				t.Internal.SafeRemoteControl.pCommandData := ADR(t.Internal.SafeRemoteCmd);
				t.Internal.SafeRemoteControl.SafeLOGICID := t.IN.CFG.SafeLogicID;
			END_IF
			
		SRWrap_ST_GETSTATUS:
			//Get Status
			t.Internal.continousStatus := TRUE;
			t.OUT.StatusString := 'Getting Status';
		
			IF t.Internal.SafeRemoteControl.Done AND t.Internal.SafeRemoteControl.SafeLOGICStatus.Number = UDINT_TO_UINT(t.Internal.State) THEN
				t.Internal.State := SRWrap_ST_IDLE;
				// Errors are handled by continous read
			END_IF
		
		SRWrap_ST_ERROR:
			//Wait for Ack of errors
			t.OUT.ConnectionStatus := 0;
			t.OUT.Error := TRUE;
			t.OUT.StatusString := 'Error';
			
			IF t.IN.CMD.AcknowledgeError THEN
				t.Internal.State := SRWrap_ST_DISABLED;
			ELSIF t.IN.CMD.LogIn THEN
				t.Internal.State := SRWrap_ST_CHECKING_CONNECTION;
				t.Internal.password := t.IN.PAR.Password;
				t.IN.PAR.Password := '';
				
				//Reset Error info
				t.OUT.Error := FALSE;
				t.OUT.ErrorID := 0;
				t.OUT.ErrorString := '';
			END_IF
				
	END_CASE
	
	// Continous get status and update internal safelogic
	IF t.Internal.SafeRemoteControl.Done THEN
		//Keep interal safelogic status upto date
		brsmemcpy(ADR(t.OUT.ControlStatus), ADR(t.Internal.SafeRemoteControl.SafeLOGICStatus), SIZEOF(t.OUT.ControlStatus));
	ELSIF t.Internal.SafeRemoteControl.Error AND 
		(t.Internal.continousStatus 
		OR t.Internal.SafeRemoteCmd.Number = UDINT_TO_UINT(SRWrap_ST_IDLE)
		OR t.Internal.SafeRemoteCmd.Number = UDINT_TO_UINT(SRWrap_ST_LOGGEDIN)
		OR t.Internal.SafeRemoteCmd.Number = UDINT_TO_UINT(SRWrap_ST_GETSTATUS)) THEN
		//Ignore certain errors
		IF (NOT (t.Internal.SafeRemoteControl.StatusID = safeERR_RC_ENTER_PW))
			OR t.Internal.SafeRemoteCmd.Number = UDINT_TO_UINT(SRWrap_ST_GETSTATUS) THEN
			t.OUT.ErrorID := t.Internal.SafeRemoteControl.StatusID;
			t.OUT.ErrorString := 'Get Status: ';
			SafeRemoteErrorString(t.OUT.ErrorID,t.OUT.ErrorString);
			t.Internal.State := SRWrap_ST_ERROR;
		END_IF
	ELSIF NOT t.Internal.SafeRemoteControl.Busy AND t.Internal.continousStatus THEN
		t.Internal.SafeRemoteCmd.Number := UDINT_TO_UINT(t.Internal.State); //Set command number
		t.Internal.SafeRemoteCmd.Command := safeCMD_STATUS;
		t.Internal.SafeRemoteCmd.Data := 0;
		t.Internal.SafeRemoteCmd.Password := t.Internal.password;
		t.Internal.SafeRemoteCmd.Version := safeVERSION_R107;
			
		t.Internal.SafeRemoteControl.SafeLOGICID := t.IN.CFG.SafeLogicID;
		t.Internal.SafeRemoteControl.pCommandData := ADR(t.Internal.SafeRemoteCmd);
		t.Internal.SafeRemoteControl.Execute := TRUE;
	END_IF
	
	// FUB CALLS
	t.Internal.SafeDownload();
	t.Internal.SafeRemoteControl();
	t.Internal.SafeInfo();
	t.Internal.timeOut();
	
	// Reset Executes
	t.Internal.SafeDownload.Execute := FALSE;
	t.Internal.SafeRemoteControl.Execute := FALSE;
	t.Internal.SafeInfo.Execute := FALSE;
	t.Internal.timeOut.IN := FALSE;
	
	// Set Outputs	
	IF t.OUT.ControlStatus.SafeKEYChanged > 0 THEN
		t.OUT.AckKeyNeeded := TRUE;
		t.OUT.NumAckModulesNeeded := 0;
	ELSE
		t.OUT.NumAckModulesNeeded := t.OUT.ControlStatus.NumberOfMissingModules + t.OUT.ControlStatus.NumberOfUDIDMismatches;
		t.OUT.AckKeyNeeded := FALSE;
	END_IF
	IF t.OUT.NumAckModulesNeeded > 0 AND NOT t.OUT.AckKeyNeeded THEN
		// Must acknowledge safe key first
		t.OUT.AckModuleNeeded := TRUE;
		IF t.OUT.NumAckModulesNeeded > 4 THEN
			t.OUT.AckNModuleNeeded := TRUE;
		ELSE
			t.OUT.AckNModuleNeeded := FALSE;
		END_IF	
	ELSE
		t.OUT.AckModuleNeeded := FALSE;
		t.OUT.AckNModuleNeeded := FALSE;
	END_IF
	IF t.OUT.ControlStatus.NumberOfDifferentFirmware > 0 AND NOT t.OUT.AckKeyNeeded AND NOT t.OUT.AckModuleNeeded THEN	
		// Must acknowledge safekey and modules first
		t.OUT.AckFirmwareNeeded := TRUE;
	ELSE
		t.OUT.AckFirmwareNeeded := FALSE;
	END_IF
	
	// Reset inputs
	t.IN.CMD.AcknowledgeError := 0;
	t.IN.CMD.AcknowledgeKey := 0;
	t.IN.CMD.Acknowledge1Module := 0;
	t.IN.CMD.Acknowledge2Module := 0;
	t.IN.CMD.Acknowledge3Module := 0;
	t.IN.CMD.Acknowledge4Module := 0;
	t.IN.CMD.AcknowledgeNModule := 0;
	t.IN.CMD.AcknowledgeFirmware := 0;
	t.IN.CMD.Unlock := 0;
	t.IN.CMD.Transfer := 0;
	t.IN.CMD.FormatSafeKey := 0;
	t.IN.CMD.ReadStatus := 0;
	t.IN.CMD.LogIn := 0;
	t.IN.CMD.LogOut := 0;
	t.IN.CMD.SetPassword := 0;
	t.IN.CMD.Scan := 0;

	// Set return value to prevent warnings
	SafeRemoteFn_Cyclic:=t.OUT.Error;
END_FUNCTION


// SafeRemoteErrorString
// Internal function used to get error text associated with an error ID
// @Id: Error ID
// @ErrorString: Address of string for the text be concated to 
FUNCTION SafeRemoteErrorString
	CASE Id OF
		0: ErrorString:=CONCAT(ErrorString,'No error');
		20605: ErrorString:=CONCAT(ErrorString,'Object NOT found');
		20609: ErrorString:=CONCAT(ErrorString,'Data object NOT found');
		20700: ErrorString:=CONCAT(ErrorString,'The specified path is invalid');
		20798: ErrorString:=CONCAT(ErrorString,'Error in device manager');
		36100: ErrorString:=CONCAT(ErrorString,'Incorrect version OF command structure');
		36101: ErrorString:=CONCAT(ErrorString,'Incorrect password length');
		36102: ErrorString:=CONCAT(ErrorString,'No UDID specified FOR safety controller');
		36103: ErrorString:=CONCAT(ErrorString,'Error allocating internal memory');
		36104: ErrorString:=CONCAT(ErrorString,'Internal error');
		36105: ErrorString:=CONCAT(ErrorString,'Communication timeout');
		36106: ErrorString:=CONCAT(ErrorString,'No command specified');
		36107: ErrorString:=CONCAT(ErrorString,'Invalid command specified FOR Enter command');
		36108: ErrorString:=CONCAT(ErrorString,'No password specified FOR Enter command');
		36109: ErrorString:=CONCAT(ErrorString,'No new password specified FOR change');
		36110: ErrorString:=CONCAT(ErrorString,'Invalid command FOR reading back status');
		36111: ErrorString:=CONCAT(ErrorString,'Incorrect data length FOR status information returned BY system');
		36112: ErrorString:=CONCAT(ErrorString,'No password specified FOR download');
		36113: ErrorString:=CONCAT(ErrorString,'Incorrect protocol version OR header error');
		36114: ErrorString:=CONCAT(ErrorString,'File already open');
		36115: ErrorString:=CONCAT(ErrorString,'File invalid');
		36116: ErrorString:=CONCAT(ErrorString,'File too large');
		36117: ErrorString:=CONCAT(ErrorString,'Write error');
		36118: ErrorString:=CONCAT(ErrorString,'Error at end OF stream');
		36119: ErrorString:=CONCAT(ErrorString,'Incorrect checksum');
		36120: ErrorString:=CONCAT(ErrorString,'Mismatch OF specified UDID with UDID OF safety controller');
		36121: ErrorString:=CONCAT(ErrorString,'Incorrect file size');
		36122: ErrorString:=CONCAT(ErrorString,'No authorization TO write, incorrect password');
		36123: ErrorString:=CONCAT(ErrorString,'Error retrieving file information');
		36124: ErrorString:=CONCAT(ErrorString,'Read error');
		36125: ErrorString:=CONCAT(ErrorString,'Write error');
		36126: ErrorString:=CONCAT(ErrorString,'Constant signal TRUE on parameter in command structure');
		36127: ErrorString:=CONCAT(ErrorString,'Comparison failed FOR read back data');
		36128: ErrorString:=CONCAT(ErrorString,'Unknown OR invalid download type');
		36129: ErrorString:=CONCAT(ErrorString,'Incorrect data specified FOR download');
		36130: ErrorString:=CONCAT(ErrorString,'Unknown OR invalid upload type');
		36131: ErrorString:=CONCAT(ErrorString,'Error reading from file');
		36132: ErrorString:=CONCAT(ErrorString,'Required input buffer is NULL');
		36133: ErrorString:=CONCAT(ErrorString,'Required input buffer too small');
		36134: ErrorString:=CONCAT(ErrorString,'File empty OR NOT found on safety controller');
		36135: ErrorString:=CONCAT(ErrorString,'Error retrieving file information');
		36136: ErrorString:=CONCAT(ErrorString,'Unknown OR invalid SafeLOGIC information');
		36137: ErrorString:=CONCAT(ErrorString,'Remote control command returning error');
		36138: ErrorString:=CONCAT(ErrorString,'Invalid password');
		36180: ErrorString:=CONCAT(ErrorString,'Table type NOT supported');
		36181: ErrorString:=CONCAT(ErrorString,'Invalid table instance');
		36182: ErrorString:=CONCAT(ErrorString,'Null pointer specified');
		36183: ErrorString:=CONCAT(ErrorString,'Number OF table entries is 0 OR unable TO determine table length (e.g. table type NOT supported)');
		36184: ErrorString:=CONCAT(ErrorString,'Username longer than 47 bytes plus string terminator');
		36185: ErrorString:=CONCAT(ErrorString,'Table type dependent copy FUNCTION returning error');
		36186: ErrorString:=CONCAT(ErrorString,'Type-dependent table check failed');
		36187: ErrorString:=CONCAT(ErrorString,'Unable TO export HMI application data from the generated raw table data');
		36188: ErrorString:=CONCAT(ErrorString,'Tables CRC protection returned error');
		36189: ErrorString:=CONCAT(ErrorString,'Input "AckData" was set although this is NOT permitted');
		36190: ErrorString:=CONCAT(ErrorString,'The step switching mechanism OF the FUNCTION block is in an invalid step');
		36191: ErrorString:=CONCAT(ErrorString,'The FUNCTION block is waiting FOR HMI application data TO be acknowledged');
		65535: ErrorString:=CONCAT(ErrorString,'FUNCTION block still working');
	END_CASE
	
	// Set return value to prevent warnings
	SafeRemoteErrorString:= 0;
END_FUNCTION
