
FUNCTION SafeRemoteErrorString : BOOL
	VAR_INPUT
		Id : UINT;
		ErrorString : STRING[320];
	END_VAR
END_FUNCTION

FUNCTION SafeRemoteFn_Cyclic : BOOL
	VAR_IN_OUT
		t : SRWrap_typ;
	END_VAR
END_FUNCTION
