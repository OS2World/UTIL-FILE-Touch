TITLE	OS/2 TOUCH -- update file last write date and time
PAGE	66,80

COMMENT /**********************************************************************

    TOUCH.ASM

    Updates the named files' last write date and time to the current
    date and time. Accepts wildcard filenames.

    Assemble with: masm -Mx touch;

    Link with: link touch,,,doscalls + djo,touch

    Usage: touch  pathname.ext

    Copyright (C)1989 David J Olson

******************************************************************************/

.286
.MODEL SMALL, PASCAL

INCL_DOSFILEMGR     EQU 1
INCL_DOSDATETIME    EQU 1

INCLUDE 	os2.inc
INCLUDE 	David's.inc

FindInfo	STRUC			    ;search results structure
    cdate	DW  (size FDATE)/2 dup (?)  ;creation date
    ctime	DW  (size FTIME)/2 dup (?)  ;creation time
    adate	DW  (size FDATE)/2 dup (?)  ;last access
    atime	DW  (size FTIME)/2 dup (?)
    wdate	DW  (size FDATE)/2 dup (?)  ;last written
    wtime	DW  (size FTIME)/2 dup (?)
    fsize	DD	?		    ;file size
    allocated	DD	?		    ;file allocation
    attributes	DW	?		    ;file attributes
    fnamesize	DB	?		    ;filename count byte
    fname	DB	13 dup(?)	    ;ASCIIZ filename
FindInfo	ENDS

FileInfo	STRUC				;search results structure
    create_d	DW  (size FDATE)/2 dup (?)  ;creation date
    create_t	DW  (size FTIME)/2 dup (?)  ;creation time
    access_d	DW  (size FDATE)/2 dup (?)  ;last access
    access_t	DW  (size FTIME)/2 dup (?)
    write_d	DW  (size FDATE)/2 dup (?)  ;last written
    write_t	DW  (size FTIME)/2 dup (?)
    filesize	DD	?		    ;file size
    allocate	DD	?		    ;file allocation
    attribute	DW	?		    ;file attributes
FileInfo	ENDS

.DATA

arg_ptr 	DD	?
subject 	DB	64 dup(0)
str_length	DW	0
matches 	DW	0

found		FindInfo<>		    ; declare structure
flength 	EQU	TYPE found

touched 	FileInfo<>
Tlength 	EQU	TYPE touched

present     DATETIME<>

here		DB	64 dup(?)
hereLength	equ	$-here

WriteLength	DW	?

newline 	DB	cr, lf
newlineLength	EQU	$-newline

notfound	DB	': no matching files found.', cr, lf
notfoundLength	EQU	$-notfound

usage		DB	cr, lf, 'USAGE: touch filename.ext', cr, lf
usageLength	EQU	$-usage



.CODE

EXTRN       Argc:FAR
EXTRN       Argv:FAR

touch	  PROC	  FAR

;   Point ES to DGROUP

	    push    ds
	    pop     es
	    assume  es:DGROUP

;   Check for commandline argument

	    push    SEG DGROUP
	    push    OFFSET DGROUP:str_length

	    call    Argc

	    cmp     WORD PTR str_length, 2
	    je      @F

	    @DosWrite stderr, usage, usageLength, WriteLength

	    @DosExit 1, 1

@@:
	    push    1
	    push    SEG DGROUP
	    push    OFFSET DGROUP:arg_ptr
	    push    SEG DGROUP
	    push    OFFSET DGROUP:str_length
	    call    Argv

	    mov     cx, str_length	       ;Number of characters
	    mov     di, OFFSET DGROUP:subject
	    lds     si, arg_ptr
	    cld
    rep     movsb
	    xor     ax, ax
	    stosb			    ;NULL terminated string
	    push    es
	    pop     ds

	    @DosGetDateTime present

	    call    FSearch

	    mov     ax, matches
	    or	    ax, ax
	    jnz     @F

	    @DosWrite stdout, newline, newlineLength, WriteLength

	    @DosWrite stdout, subject, [str_length], WriteLength

	    @DosWrite stdout, notfound, notfoundLength, WriteLength
@@:
	    @DosExit 1, 0

touch	  ENDP




COMMENT /**********************************************************************

    FSearch:	Scan current directory for filenames matching "subject".

    Arguments:	none

    Globals:	matches, subject, found.

    Locals:	shandle, scount.

    Returns:	none

    Registers:	ax.

******************************************************************************/

FSearch     PROC    NEAR USES ax

LOCAL	shandle:WORD, scount:WORD

	    mov     shandle, 0FFFFH	    ;initialize search handle
	    mov     scount, 1		    ;max matches to return

        @DosFindFirst subject shandle 0000H found flength scount 0

	    or	    ax, ax
	    jnz     FSdone		    ;no match found

@@:
	    inc     matches		    ;number of matches found
	    call    touchfile

	    @DosFindNext [shandle] found flength scount

	    or	    ax, ax
	    jz	    @B			    ;Found another match

FSdone:
	    @DosFindClose [shandle]

	    ret

FSearch     ENDP




COMMENT /**********************************************************************

    touchfile:	Open file, get handle, get file info, change date & time,
		set file info, close file.

    Arguments:	none

    Globals:	found, touched, seconds, minutes, hours, day, month, year

    Locals:	thandle

    Returns:	ERROR or NOERROR

    Registers:

******************************************************************************/

touchfile   PROC    NEAR

LOCAL	thandle:WORD, action:WORD

        @DosOpen found.fname thandle action NULL NULL 0001H 0022H 0
	    or	    ax, ax
	    jnz     @F

	    @DosQFileInfo [thandle] 0001H touched Tlength
	    or	    ax, ax
	    jnz     @F

;touched.write_t =  (present.date_seconds >> 1) |
;           (present.date_minutes << 5) |
;           (present.date_hours << 11)

	    xor     ax, ax
        mov     al, present.date_seconds      ;seconds/2 to bits 0-4
	    shr     ax, 1
	    and     ax, 001FH
	    mov     touched.write_t, ax
        mov     al, present.date_minutes     ;minutes to bits 5-10
	    and     ax, 003FH
	    shl     ax, 05H
	    or	    touched.write_t, ax
	    xor     ah, ah
        mov     al, present.date_hours       ;hours to bits 11-15
	    xchg    ah, al
	    shl     ax, 04H
	    or	    touched.write_t, ax

;touched.write_d =  (present.date_day & 001F) |
;           ((present.date_month & 000F) << 5) |
;           ((present.date_year - 1980) << 9)

	    xor     ax, ax
        mov     al, present.date_day
	    and     al, 1FH
	    mov     touched.write_d, ax     ;day to bits 0-4
        mov     al, present.date_month
	    and     al, 0FH
	    shl     ax, 05H
	    or	    touched.write_d, ax     ;month to bits 5-8
        mov     ax, present.date_year
	    sub     ax, 1980
	    shl     ax, 09H
	    or	    touched.write_d, ax     ;year to bits 9-15

	    @DosSetFileInfo [thandle] 0001H touched Tlength
	    or	    ax, ax
	    jnz     @F

@@:
	    @DosClose [Thandle]
	    ret

touchfile   ENDP

end touch
