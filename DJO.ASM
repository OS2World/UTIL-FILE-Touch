TITLE	Argc -- commandline parameter counter
PAGE	66,80

COMMENT /**********************************************************************

    DJO.ASM

    Dynamic Link Library of routines for assembly language programming

    Assenble with: masm -Mx djo;

    Link with: link djo, djo.dll,, doscalls, djo

    Functions exported:
			InitOS()
			Argc( count:PW )
			Argv( number:W, arg:PD, length:PW )

    Copyright (C)1989 David J Olson

******************************************************************************/

.286
.MODEL SMALL, PASCAL

cr		equ	0DH
lf		equ	0AH
blank		equ	20H
tab		equ	09H
NULL		equ	00H

stdout  	equ	1
stderr  	equ	2

INCL_DOSMISC	equ	1

INCLUDE 	os2.inc

.DATA

Environment	dw	?		    ; Environment segment
Arguments	dw	?		    ; Offset to commandline args


.CODE

COMMENT /**********************************************************************

    InitOS2

    Maintains the environment data

    Inputs: All Registers

    Returns: NO_ERROR

******************************************************************************/

InitOS2 PROC	FAR

	    @DosGetEnv Environment, Arguments
	    or	    ax, ax
	    jnz     fail
	    mov     ax, 1		    ; 1 indicates success,
	    ret
fail:
	    xor     ax, ax		    ; 0 failure, as DLL initializes
	    ret

InitOS2 ENDP



COMMENT /**********************************************************************

    Argc

    Counts the number of arguments on the commandline

    Inputs: far pointer to count

    Returns: NO_ERROR

******************************************************************************/

Argc	PROC	FAR USES DS ES BX CX, count:FAR PTR

	    mov     ax, seg DGROUP
	    mov     ds, ax
	    mov     es, Environment
	    mov     bx, Arguments
	    mov     ax, 1		    ; count = 1
@@:
	    inc     bx			    ; First field is blank??
	    cmp     BYTE PTR es:[bx], 0
	    jne     @B
argc1:
	    mov     cx, -1		    ; Set flag = outside argument
argc2:
	    inc     bx

	    cmp     BYTE PTR es:[bx], 0
	    je	    argc3		    ; Exit if NULL

	    cmp     BYTE PTR es:[bx], blank
	    je	    argc1

	    cmp     BYTE PTR es:[bx], tab
	    je	    argc1

	    jcxz    argc2

	    inc     ax			    ; Increment count
	    not     cx			    ; Set flag = inside argument
	    jmp     argc2
argc3:
	    les     bx, count
	    mov     es:[bx], ax 	    ; Save count
	    mov     ax, NO_ERROR
	    ret

Argc	ENDP



COMMENT /**********************************************************************

    Argv

    Parses the arguments on the commandline. Places pointer to argument[n] in
    argument string. If n=0, then points to full path name.

    Inputs: subscript, far pointer to argument string, far pointer to length

    Returns: NO_ERROR

******************************************************************************/

Argv	PROC	FAR USES DS ES BX CX DI, number:WORD, arg:FAR PTR DWORD, lngth:FAR PTR

	    mov     ax, seg DGROUP
	    mov     ds, ax
	    mov     es, Environment
	    mov     bx, Arguments
	    mov     ax, number
	    or	    ax, ax
	    jz	    argv8		    ; Get program pathname.ext

argv1:

	    inc     bx			    ; Scan past first field
	    cmp     BYTE PTR es:[bx], 0
	    jne     argv1
	    xor     ah, ah		    ; Initialize arg counter

argv2:

	    mov     cx, 0FFFFH		    ; Set flag = outside argument

argv3:

	    inc     bx
	    cmp     BYTE PTR es:[bx], NULL
	    je	    argv7		    ; Exit if NULL

	    cmp     BYTE PTR es:[bx], blank
	    je	    argv2

	    cmp     BYTE PTR es:[bx], tab
	    je	    argv2

	    jcxz    argv3
	    inc     ah			    ; arg[n] + 1
	    cmp     ah, al		    ; is this it?
	    je	    argv4		    ; Get length
	    not     cx			    ; Set flag = inside argument
	    jmp     argv3

argv4:

	    mov     ax, bx		    ; save starting address

argv5:

	    inc     bx			    ; point to next character
	    cmp     byte ptr es:[bx], 0
	    je	    argv6

	    cmp     byte ptr es:[bx], blank
	    je	    argv6

	    cmp     byte ptr es:[bx], tab
	    jne     argv5

argv6:

	    xchg    bx, ax		    ; set es:bx = argument address
	    sub     ax, bx		    ; and ax = length
	    jmp     argv10

argv7:

	    mov     ax, 01H		    ; set ax != 0 => error condition
	    jmp     argv11

argv8:	; argv[0]

	    xor     di, di
	    xor     al, al
	    mov     cx, 0FFFFH
	    cld

argv9:	; Scan for double null byte

    repne   scasb
	    scasb

	    jne     argv9
	    mov     bx, di		    ; save program name address
	    mov     cx, 0FFFFH

    repne   scasb
	    not     cx			    ; convert cx to length
	    dec     cx
	    mov     ax, cx		    ; return length in cx

argv10:

	    lds     di, arg		    ; address of first local variable
	    mov     ds:[di], bx 	    ; store argument pointer
	    mov     ds:[di+2], es
	    lds     di, lngth		   ; address of second local variable
	    mov     ds:[di], ax 	    ; store argument length
	    xor     ax, ax		    ; ax = 0 => success

argv11:

	    ret

argv	endp

end	InitOS2


END
