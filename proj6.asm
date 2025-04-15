TITLE Project 6     proj6.asm

; Description: String Primitives and Macros
	; This program opens a user defined .txt file and stores the ascii contents in  
	; an array. Once stored, the array will be parsed and all elements will be moved 
	; to an array of integers. This final array will finally be used and reversed
	; and printed. 
	;
	; This program is complete as it will greet and part the user. It utilizes  
	; macros, procedures & constants, & leverages the stack to pass data around. 
	;

INCLUDE Irvine32.inc
;##################################################################################
;	macros																		  #
;##################################################################################
; ---------------------------------------------------------------------------------
; Name: mGetString
; display a prompt and get user input, storing that input in memory.
;
; Preconditions: array must be able to accommodate user input 
;
; Receives:
;	strOffset		= array address
;	inputBuffer		= array buffer
;	maxChars		= array length
;	byteCount		= character count
;
; Returns: none
; ---------------------------------------------------------------------------------
mGetString		MACRO	strOffset, inputBuffer, maxChars, byteCount
	PUSH	EAX
	PUSH	ECX
	PUSH	EDX

	mDisplayString	OFFSET	strOffset					; print prompt

	MOV		EDX, inputBuffer							; pointer to buffer
	MOV		ECX, maxChars								; max amount of characters
	CALL	ReadString									; content stored in 
	MOV		byteCount, EAX								; move # of characters

	POP		EDX
	POP		ECX
	POP		EAX
ENDM

; ---------------------------------------------------------------------------------
; Name: mDisplayString
; display a string stored in memory
;
; Preconditions: string must exist
;
; Receives:
;	strOffset		= string address
;
; Returns: none
; ---------------------------------------------------------------------------------
mDisplayString	MACRO	strOffset
	PUSH	EDX
	MOV		EDX, strOffset
	CALL	WriteString
	POP		EDX
ENDM

; ---------------------------------------------------------------------------------
; Name: mDisplayChar
; display an ascii string character stored in memory
;
; Preconditions: none
;
; Receives:
;	chrOffset		= character address 
;
; Returns: none
; ---------------------------------------------------------------------------------
mDisplayChar	MACRO	chrOffset
	PUSH	EAX
	MOV		AL, chrOffset
	CALL	WriteChar
	POP		EAX
ENDM

;##################################################################################
;	constants																	  #
;##################################################################################
TEMPS_PER_DAY	=	24
DELIMITER		=	44									;	ASCII for ','
MAX_SIZE		=	100

;##################################################################################
;	variables																	  #
;##################################################################################
.data

; prompts
rules1			BYTE	"Welcome to the intern error-corrector! Made by Joseph Gilmore",13,10,0
rules2			BYTE	"I'll read a ','-delimited file storing a series of temperature values. The file must be ASCII-formatted.",13,10,0
rules3			BYTE	"I'll then reverse the ordering and provide the corrected temperature ordering as a printout!",13,10,0
prompt1			BYTE	"Enter the name of the file to be read: ",0
fileNameError	BYTE    "ERROR: Invalid Filename. Please check the directory in which you saved the .txt file.",0
readError		BYTE    "ERROR: Cannot read file",0
outputString	BYTE	"Here's the corrected temperature order:",13,10,0
exitString		BYTE	"Hope that helps resolve the issue, goodbye!",0

fileHandle		DWORD	?
bytesRead       DWORD   ?
fileBuffer		SDWORD	9999 DUP(0)						; ascii array			(output from mGetString)
tempArray		SDWORD	TEMPS_PER_DAY DUP(0)			; int array				(output from ParseTempsFromString)
inputCount		DWORD	?								; length of tempArray	(output from mGetString)

;##################################################################################
;	main																		  #
;##################################################################################
.code
main PROC

	mDisplayString	OFFSET	rules1	
	mDisplayString	OFFSET	rules2		
	mDisplayString	OFFSET	rules3	

	mGetString		OFFSET prompt1, OFFSET fileBuffer, MAX_SIZE, inputCount	; print prompt1
	CALL	CrLf
	mDisplayString	OFFSET outputString

	MOV		EDX, OFFSET fileBuffer
	CALL	OpenInputFile								; load file name and store in fileHandle
	MOV		fileHandle, EAX

	CMP		EAX, INVALID_HANDLE_VALUE					; begin checking file name and path
	JNE		_validName

	mDisplayString	OFFSET	fileNameError				; print error
	JMP		_end

  _validName:
	MOV		EAX, fileHandle
	MOV		EDX, OFFSET fileBuffer 
	MOV		ECX, SIZEOF fileBuffer
	CALL	ReadFromFile
	MOV		bytesRead, EAX
	JNC		_validRead									; jump if carry flag not set

	mDisplayString	OFFSET	readError
	JMP		_end
  
  _validRead:
	CALL	CrLf

	PUSH	OFFSET tempArray
	PUSH	OFFSET fileBuffer
	CALL	ParseTempsFromString						; begin parsing temps from string

	PUSH	OFFSET tempArray
	CALL	WriteTempsReverse							; begin writing temps from array in reverse

	mDisplayString	OFFSET exitString					; bye bye!
	CALL	CrLf

	_end:

	Invoke ExitProcess,0	; exit to operating system
main ENDP


;##################################################################################
;	procedures																	  #
;##################################################################################
; ---------------------------------------------------------------------------------
; Name: ParseTempsFromString
; takes in an array of numbers separated by a delimiter, parsing them into an array
; of integers
; Preconditions: requires an array with delimiter separated elements to parse and 
; an array of TEMPS_PER_DAY size to write to
; Postconditions: none
; Receives: 
;	[EBP + 12]	= OFFSET tempArray			- output
;	[EBP + 8]	= OFFSET fileBuffer			- input
;	[EBP + 4]	= return address
; Returns: temp array = output
; ---------------------------------------------------------------------------------
ParseTempsFromString PROC
	LOCAL sign:SDWORD

	PUSHAD
	CLD													; reset direction flag before we do anything
	MOV		ESI, [EBP + 8]								; data input - fileBuffer
	MOV		EDI, [EBP + 12]								; data output - tempArray (STOSB will place data here when called)

	MOV		EAX, 0										; accumulator - start at 0
	MOV		ECX, TEMPS_PER_DAY							; maximum items in array

	_beginArrayLoop:									; begin array loop
		LODSB											; puts first byte into AL, increase ESI each loop
		MOV		EBX, 0									; holds value of number in number loop
		MOV		sign, 1									; default to positive number

		CMP		AL, '-'									; check for negative (-)
		JNE		_checkPositive							; jump if not negative
		MOV		sign, -1
		LODSB
		JMP		_beginDigitLoop							; - detected, jump over positive

	  _checkPositive:									; check for positive (+)
		CMP		AL, '+'
		JNE		_beginDigitLoop							; positive integers should be skipped remain but explicitly checking for +
		MOV		sign, 1
		LODSB

	  _beginDigitLoop:
			CMP		AL, DELIMITER						; check delimiter, jump out if equal
			JE		_applySign
			SUB		AL, "0"
			MOVZX	EAX, AL
			IMUL	EBX, 10

			ADD		EBX, EAX
			LODSB										; load next number, increase ESI
			JMP		_beginDigitLoop

	  _applySign:										; check if negative
		MOV		EAX, EBX
		CMP		sign, -1
		JNE		_end
		NEG		EAX

	  _end:
		STOSD											; store this data back in tempArray (EDI), increase EDI by 1
	LOOP _beginArrayLoop								; loop TEMPS_PER_DAY times (default = 24)

	POPAD
	RET		8											; dereference 8
ParseTempsFromString ENDP


; ---------------------------------------------------------------------------------
; Name: WriteTempsReverse
; takes in an array and prints it in reverse order
; Preconditions: the array must only contain integers (signed and unsigned)
; Postconditions: none
; Receives: 
;	[EBP + 8]	= OFFSET tempArray			- input
;	[EBP + 4]	= return address
; Returns: none
; ---------------------------------------------------------------------------------
WriteTempsReverse PROC
	PUSH	EBP
	MOV		EBP, ESP
	PUSHAD

	MOV		ESI, [EBP + 8]								; move first value of tempArray to ESI
	MOV		ECX, TEMPS_PER_DAY							; loop counter

	MOV		EAX, ECX
	DEC		EAX											; 0-based index
	IMUL	EAX, 4										; match eax with data size (SDWORD)
	ADD		ESI, EAX									; esi = address of last element - end prep

  _reverseLoop:
		CMP		ECX, 0									; stop loop when ecx = 0
		JZ		_finish
		MOV		EAX, [ESI]								; if not, move esi to eax and print it
		CALL	WriteInt

		mDisplayChar DELIMITER
		DEC		ECX
		STD												; set direction flag
		LODSD											; load value in memory
	JMP		_reverseLoop

  _finish:
	CALL	CrLf
	CALL	CrLf

	POPAD
	POP		EBP
	RET		8											; dereference 8
WriteTempsReverse ENDP

END main
