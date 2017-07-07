
%define red 12
xchg bx, bx                                                      
mov ax, 7c0h                     
mov ds, ax 

call sector_2
call VGA_mode
call 800h:PrintKeys-512 
call 800h:printMenu-512
call start_menu
jmp $

cursor_position:
	xor bh, bh ;page number
	mov ah, 3
	int 10h	;get Cursor Position(store in dx)
	ret

input:
	xor ah, ah	
	int 16h	;Wait for Keypress and store in al
	ret

start_menu:
	mov dh,6	;row
	mov dl,0	;column
	call 800h:Set_cursor_position-512	;place starter cursor position
	menu_choice:
		call input	;Wait for Keypress and store in al
		cmp al, '1'	;if Keypress not 1-6 jump to menu_choice
		jb menu_choice	
		cmp al, '6'
		ja menu_choice	
		call menu_cursor	;save, restore Cursor Position and print menu choice
		cmp al, '1'	;choose option in menu 1-6
		je _Add
		cmp al, '2'
		je _Sub
		cmp al, '3'
		je _Multiply
		cmp al, '4'
		je _Divide
		cmp al, '5'
		je _Free_typing
		cmp al, '6'
		je end_	;if al='6' jump to end_
		jmp menu_choice	;jump to menu_choice
	end_:
	ret

menu_cursor:	
	call cursor_position	;get Cursor Position(store in dx)
	push dx	;store dx in stack
	mov dh, 6	;row
	mov dl, 18	;column
	call 800h:Set_cursor_position-512	;place cursor position for menu choice
	mov bl, 0fh
	call 800h:printKey-512	;print menu choice
	pop dx	;return dx from stack
	xor dl, dl	;place cursor to the start of a line
	add dh, 2h	;go down 2 lines
	call 800h:Set_cursor_position-512
	ret

calculator:
	call input	;Wait for Keypress and store in al
	cmp al, '0'	;if Keypress not 0-9 jump to calculator
	jb calculator
	cmp al, '9'
	ja calculator
	call printChar	;print character at current cursor 
	sub al, '0'	
	mov ch, al
	ret
ans:
	mov al, '='
	call printChar	;print '=' at current cursor 
	mov al, ch
	add al, '0'	
	call printChar	;print character at current cursor 
	jmp menu_choice

_Add:
	call calculator
	mov al, '+'
	call printChar	;print '+' at current cursor 
	call input	;Wait for Keypress and store in al
	call printChar	;print character at current cursor 
	sub al, '0'
	add ch, al	;ch=ch+al
	jmp ans

_Sub:
	call calculator
	mov al, '-'	
	call printChar	;print '-' at current cursor 
	call input	;Wait for Keypress and store in al
	call printChar	;print character at current cursor 
	sub al, '0'
	sub ch, al	;ch=ch-al
	jmp ans

_Multiply:
	call calculator
	mov al, '*'	 
	call printChar	;print *' at current cursor
	call input	;Wait for Keypress and store in al
	call printChar	;print character at current cursor 
	sub al, '0'
	mul ch	;al=al*ch
	mov ch, al
	jmp ans

_Divide:
	call calculator
	mov al, '/'	
	call printChar	;print '/' at current cursor 
	call input	;Wait for Keypress and store in al
	call printChar	;print character at current cursor 
	sub al, '0'
	xor ah, ah
	xchg al, ch
	div ch	;al=al/ch
	mov ch, al
	jmp ans

_Free_typing:
	xor cx, cx	;cx=0
	input_Output:
		call input	;Wait for Keypress and store in al
		cmp al, 1bh
		je end_input_Output	;if user press esc exit free typing
		cmp al, 0dh
		je _enter	;if user press enter jump to _enter
		cmp al, '+'	;if Keypress not /,-,=,* or 0-9 jump to input_Output
		je math_symbol
		cmp al, '*'
		je math_symbol
		cmp al, '='
		je math_symbol
		cmp al, '-'
		je math_symbol
		cmp al, '/'
		jb input_Output
		cmp al, '9'
		ja input_Output
		math_symbol:
		push cx	;store cx in stack
		call cursor_position	;get Cursor Position(store in dx)
		call light	;highlight key press 
		call 800h:Set_cursor_position-512	;restore cursor position
		pop cx	;return cx from stack
		call checkTyping	;check if line has more than 19 characters 
		call printChar	;print character at current cursor
		inc cl	
		jmp input_Output
end_input_Output:
	mov bl, red	;bl=12(Color red)
	mov si, word[prev]	;si=last key press location
	call cursor_position	;get Cursor Position(store in dx)
	call changeColor	;restore red color to last key press
	call 800h:Set_cursor_position-512	;restore cursor position
	jmp menu_choice

_enter:
	call 800h:printEnter-512	;print Enter
	xor cl,cl		;rest number of characters
	jmp input_Output

printChar:
	mov ah, 0eh		;teletype mode 
	xor bh, bh		;page number
	mov bl, 0fh 	;color White
	int 10h			;print character at current cursor
	ret

checkTyping:
	cmp cl, 19		;max 19 characters 
	jne endCheck	;check if line has more than 19 characters 
	mov dl, al		;store al in dl
	call 800h:printEnter-512	;print Enter
	xor cx, cx		;rest number of characters
	mov al, dl		;return al to al
endCheck:
	ret

changeColor:
	push dx			;store dx in stack
	mov al, [es:si]
	add si, 3h		;go to next 3 bytes
	mov dl, [es:si]	;column
	inc si	
	mov dh, [es:si]	;row
	call 800h:Set_cursor_position-512	;set cursor position
	call 800h:printKey-512 ;print character with new color
	pop dx			;return dx from stack
	ret

light:
	jmp search				;search for key press loction
	found:
		cmp si, word[prev]	
		jne prev_choice	
		jmp end_highlight 	;if key press = previous choice jump to end_highlight
		continue_light:
		mov word[prev], si	;store key press loction in [prev]
		mov bl, 0bh			;bl=0bh(Green)
		call changeColor	;print character with new color
end_highlight:
	ret
prev_choice:
	push si				;store si in stack
	mov si, word[prev]	;si=[prev]
	mov bl, red			;bl=12(Color red)
	call changeColor	;print character with new color
	pop si				;return si from stack
	jmp continue_light
	
search:
	mov si, keyboard	;si points on keyboard
	sub si, 200h
	continue_search:
		mov bh, [es:si] ;bh receives value from cell es:si
		cmp bh, al 		;cmp bh to the required value
		je found
		cmp bh, '$'
		je end_highlight;if bh = '$' -not found-
		add si, 5 		;go to next 5 bytes
		jmp continue_search

VGA_mode:
	mov ax, 13
	int 10h	;clear screen
	ret

sector_2:
	mov ax, 800h ;address for sector number 2
	mov es, ax
	mov bx, 0h ;offset from 900h is zero
	mov ah, 02h ;BIOS function (Read disk)
	mov al, 1 ;Sectors To Read Count (512 Bytes)
	mov ch, 0 ;Cylinder [0-1023]
	mov cl, 2 ;Sector number [1-63]
	mov dh, 0 ;head = 0
	mov dl, 80h ;00h=Floppy1, 01h=Floppy2, 80h=HDD1, 81h=HDD2
	int 13h
	ret

prev dw keyboard-200h
times 510 - ($-$$) db 0        ; Fill empty bytes to binary file
dw 0aa55h                      ; Define MAGIC number at byte 512
jmp $

printEnter:
	mov al, 0dh	;ASCII character 
	mov ah, 0eh	;teletype mode 
	xor bx, bx	;bh=page number,bl=color Black
	int 10h		;print Enter
	mov al, 0ah	;ASCII character 
	int 10h
	retf

printMenu:
	call 800h:resetCursor-512	;place starter cursor position
	xor ch, ch
	mov cl, 7		;enter loop 7 times
	mov si, menu	;si points on menu
	sub si, 200h
	_loop:
	call 800h:print_row-512
	loop _loop
	retf

resetCursor:
	mov ah, 2
	xor dh, dh	;row
	xor dl, dl  ;column
	xor bh, bh	;page number
	int 10h		;place starter cursor position
	retf

print_row:
	cmp byte[es:si], 0
	je endPrint		;if [si]=0 jump to endPrint
	mov al, byte[es:si]	;al=[si]
	mov ah, 0eh		;teletype mode 
	xor bh, bh  	;page number
	mov bl, 3h		;bl=3h(color Cyan)
	int 10h			;print character at current cursor 
	inc si		
	jmp print_row
endPrint:
	call 800h:printEnter-512 ;print Enter
	inc si
	retf

Set_cursor_position:
	mov ah, 2
	xor bh, bh	;video page (0-based)
	int 10h		;place cursor position
	retf

printKey:
	xor bh, bh 	;bh=0(display page)
	mov ah, 09h	
    mov cx, 01h	;number of characters to write (Ch=0,cl=1)      
    int 10h		;print character at current cursor 
	retf

PrintKeys:
	mov si, keyboard 	;si points on keyboard
	sub si, 200h
	xor ch, ch			;column number
	xor bh, bh			;video page (0-based)
	print:
		xor dh, dh		;row number
		cmp byte[es:si], '$'
		je end_print	;if [si] = '$' jump to end_print
		mov al, [es:si]	;ASCII character to write
		push ax			;store ax in stack
		mov ah, 0ch 	;draw pixel mode
		mov al, 9 		;pixel color
		inc si	
		mov cl, [es:si]	;column number
		inc si	
		mov dl, [es:si]	;row number
		push si			;store si in stack
		call print_square	;print square
		pop si			;return si from stack
		inc si	
		mov dl, [es:si]	;column
		inc si	
		mov dh, [es:si]	;row
		call 800h:Set_cursor_position-512 ;Set cursor position
		pop ax 			;return ax from stack
		mov bl, red		;bl=0ch(red)
		call 800h:printKey-512	;print character at current cursor 
		inc si
		jmp print
	end_print:
		retf

print_square:
	pop si ;call stores ip. save it in si
	push dx ;will be needed after first column
	mov di, dx ;break point for row_loop
	add di, 12 ;square 12*12
	mov bp, cx ;brake point for column_loop
	add bp, 12
	row_loop:
		int 10h ;print pixel
		inc dx ;advance in a row
		cmp dx, di ;have we finished this row?
		jz column_loop ;yes. advance to next column
		jmp row_loop ;no. print next pixel in this column
	column_loop:
		int 10h ;draw last pixel of this column
		inc cx ;advance the column
		cmp cx, bp ;have we finished the square?
		jz sof_print_square ;yes.
		pop dx ;no. restore row number for next column
		push dx ;we have popped- we need to push again
		jmp row_loop ;start next column, row by row
sof_print_square:
	pop dx ;we have pushed once more than poppped.
	push si ;push ip for return
	ret

menu:
db "1. Add",0,"2. Sub",0,"3. Multiply",0,"4. Divide (no residue)",0 ,"5. Free typing",0,"6. Exit",0
db "enter your choice:",0
keyboard:
db 2fh , 198 , 29 , 25 , 4  		;'/'  Index:cl(column square),dl(column square),dl(column Key),dh(row Key)
db 37h , 198 , 45 , 25 , 6 			;'7'
db 34h , 198 , 61 , 25 , 8  		;'4'
db 31h , 198 , 77 , 25 , 10 		;'1'
db 2ah , 214 , 29 , 27 , 4 			;'*'
db 38h , 214 , 45 , 27 , 6 			;'8'
db 35h , 214 , 61 , 27 , 8  		;'5'
db 32h , 214 , 77 , 27 , 10   		;'2'
db 39h , 230 , 45 , 29 , 6 			;'9'
db 36h , 230 , 61 , 29 , 8  		;'6'
db 33h , 230 , 77 , 29 , 10  		;'3'
db 2dh , 246 , 45 , 31 , 6  		;'-'
db 2bh , 246 , 61 , 31 , 8 			;'+'
db 30h , 246 , 77 , 31 , 10 , '$'	;'0'
times 1022 - ($-$$) db 0            ;Fill empty bytes to binary file
dw 0aa55h     
times 2*8*63*512 - ($-$$) db 0     ; We needed create HD or floopy drive 