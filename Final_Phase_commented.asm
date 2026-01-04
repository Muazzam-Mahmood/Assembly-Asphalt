[org 0x0100]        ; Directive: Set the origin (starting address) of the program to 0x0100 (for .COM file)

jmp start           ; Jump over the data variables to the 'start' label where code execution begins

;=== GAME VARIABLES ===
road_offset: dw 0   ; Stores the current vertical scroll position for the road (16-bit)
tree_offset: dw 0   ; Stores the current vertical scroll position for the landscape (16-bit)
score: dw 0         ; Stores the player's score (16-bit)
frame_counter: dw 0 ; A counter that increments each frame, used for timing score increases
game_over: db 0     ; Flag: 0 = game running, 1 = game over (8-bit)
random_seed: dw 0x1234 ; A seed for the pseudo-random number generator
player_lane: db 1   ; Stores the player's current lane (0=Left, 1=Center, 2=Right)
old_keyboard_isr: dd 0 ; Stores the address (segment:offset) of the original keyboard ISR
old_timer_isr: dd 0 ; Stores the address (segment:offset) of the original timer ISR
esc_pressed: db 0   ; Flag: 0 = not pressed, 1 = ESC key was pressed (set by ISR)
game_paused: db 0   ; Flag: 0 = running, 1 = paused

car1: db 0, 0, 0    ; Enemy car 1. (byte 0: row, byte 1: lane, byte 2: active_flag)
car2: db 0, 0, 0    ; Enemy car 2. (row, lane, active_flag)
car3: db 0, 0, 0    ; Enemy car 3. (row, lane, active_flag)
car4: db 0, 0, 0    ; Enemy car 4. (row, lane, active_flag)

coin1: db 0, 0, 0   ; Coin 1. (row, lane, active_flag)
coin2: db 0, 0, 0   ; Coin 2. (row, lane, active_flag)
coin3: db 0, 0, 0   ; Coin 3. (row, lane, active_flag)

buffer: times 4000 dw 0 ; The off-screen buffer (2000 words = 80*25 chars * 2 bytes/char)

;=== TITLE SCREEN STRINGS ===
title_line1: db '    ___                           __    __       ', 0
title_line2: db '   /   |  _____________  ____ ___/ /_  / /_  __  ', 0
title_line3: db '  / /| | / ___/ ___/ _ \/ __ `__ \/ __ \/ / / / ', 0
title_line4: db ' / ___ |(__  |__  )  __/ / / / / / /_/ / / /_/  ', 0
title_line5: db '/_/  |_/____/____/\___/_/ /_/ /_/_.___/_/\__, /  ', 0
title_line6: db '                                        /____/   ', 0
title_line7: db '    ___                / /        __  _________ ', 0
title_line8: db '   /   |  ____________/_/________/ /_/___  ___/  ', 0
title_line9: db '  / /| | / ___ / __  / __  / ___ \/ /   / /', 0
title_line10: db ' / ___ |(__  )/ /_/ / / / /\ \_/ / /   / /', 0
title_line11: db '/_/  |_/____// .___/ / / /  \___/_/   /_/', 0
title_line12: db '            /_/                         ', 0

;=== TEAM INFO STRINGS ===
team_title: db 'Team Members:', 0
team1_name: db 'Muazzam Mahmood', 0
team1_roll: db 'Roll No: 24L-3063', 0
team2_name: db 'M.Husnain Khan', 0
team2_roll: db 'Roll No: 24L-3007', 0
semester_info: db 'Semester: Fall-2025', 0

clrscr:             ; Procedure: Clear Screen (fills video memory directly)
    push es         ; Save the Extra Segment register (ES) on the stack
    push ax         ; Save the AX register on the stack
    push di         ; Save the Destination Index register (DI) on the stack
    push cx         ; Save the CX register (counter) on the stack
    
    mov ax, 0xb800  ; Load the video memory segment address into AX
    mov es, ax      ; Set ES to point to the video memory segment
    mov di, 0       ; Set DI (destination offset) to 0 (start of video memory)
    mov ax, 0x0720  ; Load AX with the value for a space ' ' (0x20) with attribute 0x07 (light grey on black)
    mov cx, 2000    ; Load CX with 2000 (80 columns * 25 rows = 2000 characters)
    cld             ; Clear Direction Flag (so stosw increments DI)
    rep stosw       ; REPeat STOre String Word: Store AX (char+attr) at ES:[DI] and increment DI by 2, 2000 times
    
    pop cx          ; Restore the original value of CX from the stack
    pop di          ; Restore the original value of DI from the stack
    pop ax          ; Restore the original value of AX from the stack
    pop es          ; Restore the original value of ES from the stack
    ret             ; Return from the procedure

clrbuffer:          ; Procedure: Clear the off-screen buffer
    push es         ; Save ES
    push ax         ; Save AX
    push di         ; Save DI
    push cx         ; Save CX
    
    push ds         ; Push Data Segment (DS) onto the stack
    pop es          ; Pop it into ES, so ES = DS (ES now points to our data segment)
    mov di, buffer  ; Set DI to the starting address of our 'buffer'
    mov ax, 0x0020  ; Load AX with a space ' ' (0x20) and attribute 0x00 (black on black)
    mov cx, 2000    ; Load CX with 2000 (size of the buffer in words)
    cld             ; Clear Direction Flag (so stosw increments DI)
    rep stosw       ; REPeat STOre String Word: Fill the buffer with black spaces
    
    pop cx          ; Restore CX
    pop di          ; Restore DI
    pop ax          ; Restore AX
    pop es          ; Restore ES
    ret             ; Return

printchar_buf:      ; Procedure: Print a character to the off-screen buffer
    ; Input: AH=attribute, AL=char, DH=row, DL=column
    push bx         ; Save BX
    push di         ; Save DI
    push ax         ; Save AX
    
    cmp dh, 25      ; Compare DH (row) with 25 (max row)
    jge printchar_buf_skip ; Jump if Greater or Equal (if row >= 25) to skip drawing
    cmp dl, 80      ; Compare DL (column) with 80 (max column)
    jge printchar_buf_skip ; Jump if Greater or Equal (if col >= 80) to skip drawing
    
    push ax         ; Save AX (char+attr) again
    mov al, dh      ; Move DH (row) into AL
    mov bl, 80      ; Move 80 (screen width) into BL
    mul bl          ; Multiply AL by BL (row * 80). Result is in AX
    mov bl, dl      ; Move DL (column) into BL
    xor bh, bh      ; Zero out BH, so BX = DL (column)
    add ax, bx      ; Add BX (column) to AX (row * 80). AX now has the 1D position
    shl ax, 1       ; Shift Left 1 bit (position * 2) because each screen char is 2 bytes (char+attr)
    mov di, ax      ; Move the final byte offset into DI
    pop ax          ; Restore AX (the original char+attr)
    
    mov bx, buffer  ; Load the starting address of 'buffer' into BX
    add di, bx      ; Add the buffer's start address to the offset. DI now points to the correct spot in the buffer
    mov [di], ax    ; Move AX (char+attr) into the buffer at the address [DI]

printchar_buf_skip: ; Label to jump to if the character is off-screen
    pop ax          ; Restore AX
    pop di          ; Restore DI
    pop bx          ; Restore BX
    ret             ; Return

print_string_buf:   ; Procedure: Print a null-terminated string to the buffer
    ; Input: SI=string address, AH=attribute, DH=row, DL=column
    push ax         ; Save AX
    push si         ; Save Source Index (SI)
    
print_string_buf_loop: ; Loop for each character in the string
    lodsb           ; LOaD String Byte: Load byte from DS:[SI] into AL and increment SI
    cmp al, 0       ; Compare AL with 0 (the null terminator)
    je print_string_buf_done ; Jump if Equal (if end of string) to 'print_string_buf_done'
    call printchar_buf ; Call the procedure to print the character in AL
    inc dl          ; Increment DL (move to the next column)
    jmp print_string_buf_loop ; Repeat the loop
    
print_string_buf_done: ; Label for when the string is finished
    pop si          ; Restore SI
    pop ax          ; Restore AX
    ret             ; Return

flip_buffer:        ; Procedure: Copy the off-screen buffer to video memory (vsync)
    push es         ; Save ES
    push ds         ; Save DS
    push si         ; Save SI
    push di         ; Save DI
    push cx         ; Save CX
    push dx         ; Save DX
    
    ; Wait for vertical retrace to prevent screen tearing
    mov dx, 0x3DA   ; Load DX with the-VGA status port address
flip_buffer_wait1:
    in al, dx       ; Read the status port into AL
    test al, 0x08   ; Test if the vertical retrace bit (bit 3) is set
    jnz flip_buffer_wait1 ; Jump if Not Zero (if in retrace) and wait for it to end
flip_buffer_wait2:
    in al, dx       ; Read the status port into AL
    test al, 0x08   ; Test if the vertical retrace bit (bit 3) is set
    jz flip_buffer_wait2 ; Jump if Zero (if not in retrace) and wait for it to start
    
    ; Now we are in the vertical retrace interval, safe to copy
    mov ax, 0xb800  ; Load the video memory segment address into AX
    mov es, ax      ; Set ES (destination) to video memory
    push ds         ; Push DS (our data segment)
    pop ds          ; Pop it back into DS (ensuring DS is correct)
    mov si, buffer  ; Set SI (source) to the start of our 'buffer'
    xor di, di      ; Zero out DI (destination offset = 0, start of video memory)
    mov cx, 2000    ; Load CX with 2000 (number of words to copy)
    cld             ; Clear Direction Flag (so movsw increments SI and DI)
    rep movsw       ; REPeat MOVe String Word: Copy 2000 words from DS:[SI] to ES:[DI]
    
    pop dx          ; Restore DX
    pop cx          ; Restore CX
    pop di          ; Restore DI
    pop si          ; Restore SI
    pop ds          ; Restore DS
    pop es          ; Restore ES
    ret             ; Return

get_random:         ; Procedure: Generate a pseudo-random number (Linear Congruential Generator)
    ; Output: AX = random 16-bit number
    push bx         ; Save BX
    push dx         ; Save DX
    
    mov ax, [random_seed] ; Load the current seed into AX
    mov bx, 25173   ; Load multiplier into BX
    mul bx          ; Multiply AX by BX. Result is in DX:AX (we only care about AX)
    add ax, 13849   ; Add the increment
    mov [random_seed], ax ; Save the new seed for next time
    
    pop dx          ; Restore DX
    pop bx          ; Restore BX
    ret             ; Return

delay:              ; Procedure: A simple (and inefficient) delay loop
    push cx         ; Save CX
    push ax         ; Save AX
    
    mov cx, 0x0001  ; Set outer loop counter
delay_outer_d:
    push cx         ; Save outer loop counter
    mov cx, 0xFFFF  ; Set inner loop counter to a large value
delay_inner_d:
    nop             ; No Operation (waste one clock cycle)
    loop delay_inner_d ; Decrement CX, loop if CX != 0
    pop cx          ; Restore outer loop counter
    loop delay_outer_d ; Decrement CX, loop if CX != 0
    
    pop ax          ; Restore AX
    pop cx          ; Restore CX
    ret             ; Return

show_main_menu:     ; Procedure: Display the main menu screen
    mov ax, 0x0003  ; AH=0x00 (Set Video Mode), AL=0x03 (80x25 16-color text mode)
    int 0x10        ; Call BIOS video interrupt (resets screen)
    
    mov ah, 0x01    ; AH=0x01 (Set Cursor Shape)
    mov ch, 0x32    ; CH=0x32 (bits 0-4=start line, bit 5=invisible)
    mov cl, 0x00    ; CL=end line
    int 0x10        ; Call BIOS video interrupt (hides the cursor)
    
    call clrbuffer  ; Clear our off-screen buffer
    
    ; Draw team info box in top right corner
    mov dh, 0       ; DH = row 0
    mov dl, 52      ; DL = col 52
    mov bl, 32      ; BL = width 32
    mov bh, 8       ; BH = height 8
    mov ah, 0x0B    ; AH = attribute (light cyan on black)
    call draw_box_buf ; Call procedure to draw a box
    
    ; Draw team title centered
    mov dh, 1       ; DH = row 1
    mov dl, 55      ; DL = col 55
    mov ah, 0x0E    ; AH = attribute (yellow on black)
    mov si, team_title ; SI = address of team_title string
    call print_string_buf ; Print the string
    
    ; Draw team member 1 info
    mov dh, 2       ; row 2
    mov dl, 55      ; col 55
    mov ah, 0x0B    ; attribute (light cyan)
    mov si, team1_name ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 3       ; row 3
    mov dl, 55      ; col 55
    mov ah, 0x0B    ; attribute (light cyan)
    mov si, team1_roll ; SI = address of string
    call print_string_buf ; Print
    
    ; Draw team member 2 info
    mov dh, 4       ; row 4
    mov dl, 55      ; col 55
    mov ah, 0x0B    ; attribute
    mov si, team2_name ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 5       ; row 5
    mov dl, 55      ; col 55
    mov ah, 0x0B    ; attribute
    mov si, team2_roll ; SI = address of string
    call print_string_buf ; Print
    
    ; Draw semester info centered
    mov dh, 6       ; row 6
    mov dl, 55      ; col 55
    mov ah, 0x0E    ; attribute (yellow)
    mov si, semester_info ; SI = address of string
    call print_string_buf ; Print
    
    ; Draw title ASCII art - centered
    mov dh, 8       ; row 8
    mov dl, 16      ; col 16
    mov ah, 0x0E    ; attribute (yellow)
    mov si, title_line1 ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 9       ; row 9
    mov dl, 16      ; col 16
    mov ah, 0x0A    ; attribute (light green)
    mov si, title_line2 ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 10      ; row 10
    mov dl, 16      ; col 16
    mov ah, 0x0B    ; attribute (light cyan)
    mov si, title_line3 ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 11      ; row 11
    mov dl, 16      ; col 16
    mov ah, 0x09    ; attribute (light blue)
    mov si, title_line4 ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 12      ; row 12
    mov dl, 16      ; col 16
    mov ah, 0x0D    ; attribute (light magenta)
    mov si, title_line5 ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 13      ; row 13
    mov dl, 16      ; col 16
    mov ah, 0x0C    ; attribute (light red)
    mov si, title_line6 ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 14      ; row 14
    mov dl, 16      ; col 16
    mov ah, 0x0E    ; attribute (yellow)
    mov si, title_line7 ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 15      ; row 15
    mov dl, 16      ; col 16
    mov ah, 0x0A    ; attribute (light green)
    mov si, title_line8 ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 16      ; row 16
    mov dl, 16      ; col 16
    mov ah, 0x0B    ; attribute (light cyan)
    mov si, title_line9 ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 17      ; row 17
    mov dl, 16      ; col 16
    mov ah, 0x09    ; attribute (light blue)
    mov si, title_line10 ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 18      ; row 18
    mov dl, 16      ; col 16
    mov ah, 0x0D    ; attribute (light magenta)
    mov si, title_line11 ; SI = address of string
    call print_string_buf ; Print
    
    mov dh, 19      ; row 19
    mov dl, 16      ; col 16
    mov ah, 0x0C    ; attribute (light red)
    mov si, title_line12 ; SI = address of string
    call print_string_buf ; Print
    
    ; Draw "Press P to Play" - centered (manually, char by char)
    mov dh, 21      ; row 21
    mov dl, 31      ; col 31
    mov ah, 0x0F    ; attribute (bright white)
    mov al, 'P'     ; AL = character 'P'
    call printchar_buf ; Print
    inc dl          ; next column
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov ah, 0x0A    ; Change attribute to light green for 'P'
    mov al, 'P'
    call printchar_buf
    inc dl
    mov ah, 0x0F    ; Change attribute back to bright white
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'P'
    call printchar_buf
    inc dl
    mov al, 'l'
    call printchar_buf
    inc dl
    mov al, 'a'
    call printchar_buf
    inc dl
    mov al, 'y'
    call printchar_buf
    
    ; Draw "Press ESC to Exit" - centered below
    mov dh, 23      ; row 23
    mov dl, 30      ; col 30
    mov ah, 0x0F    ; attribute (bright white)
    mov al, 'P'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov ah, 0x0C    ; Change attribute to light red for 'ESC'
    mov al, 'E'
    call printchar_buf
    inc dl
    mov al, 'S'
    call printchar_buf
    inc dl
    mov al, 'C'
    call printchar_buf
    inc dl
    mov ah, 0x0F    ; Change attribute back to bright white
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'E'
    call printchar_buf
    inc dl
    mov al, 'x'
    call printchar_buf
    inc dl
    mov al, 'i'
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    
    call flip_buffer ; Copy the completed buffer to the screen

menu_wait_for_key:  ; Loop: Wait for user input on the main menu
    cmp byte [esc_pressed], 1 ; Check if the ESC key flag (from ISR) is set
    je menu_handle_esc ; Jump if Equal (if ESC pressed) to handle exit
    
    mov ah, 0x01    ; AH=0x01 (Check for keypress status)
    int 0x16        ; Call BIOS keyboard interrupt
    jz menu_wait_for_key ; Jump if Zero (no key pressed) back to waiting
    
    mov ah, 0x00    ; AH=0x00 (Get keypress)
    int 0x16        ; Call BIOS keyboard interrupt (removes key from buffer)
    
    cmp al, 'p'     ; Compare AL (ASCII key) with 'p'
    je start_game   ; Jump if Equal to 'start_game'
    cmp al, 'P'     ; Compare AL with 'P'
    je start_game   ; Jump if Equal to 'start_game'
    
    jmp menu_wait_for_key ; If not 'p' or 'ESC', loop again

menu_handle_esc:    ; Label: Handle exiting from the main menu
    ; Exit directly from main menu - no confirmation
    xor ax, ax      ; Zero out AX
    mov es, ax      ; Set ES to 0 (to access Interrupt Vector Table)
    
    ; Restore keyboard ISR
    mov ax, [old_keyboard_isr] ; Get offset of old ISR
    mov [es:9*4], ax    ; Restore offset to IVT
    mov ax, [old_keyboard_isr+2] ; Get segment of old ISR
    mov [es:9*4+2], ax  ; Restore segment to IVT
    
    ; Restore timer ISR
    mov ax, [old_timer_isr] ; Get offset of old ISR
    mov [es:8*4], ax    ; Restore offset to IVT
    mov ax, [old_timer_isr+2] ; Get segment of old ISR
    mov [es:8*4+2], ax  ; Restore segment to IVT
    
    mov ax, 0x0003  ; AH=0x00, AL=0x03 (Set 80x25 text mode)
    int 0x10        ; Call BIOS video interrupt (clears screen, shows cursor)
    mov ax, 0x4c00  ; AH=0x4C (Terminate program), AL=0x00 (return code)
    int 0x21        ; Call DOS interrupt

start_game:         ; Label: Point to return to after 'p' is pressed
    ret             ; Return (to 'main_menu_start' which then falls into 'game_loop')

draw_hline:         ; Procedure: Draw a horizontal line in the buffer
    ; Input: AH=attr, AL=char, DH=row, DL=start_col, BL=length
    push cx         ; Save CX
    push dx         ; Save DX
    
    mov cl, bl      ; Move BL (length) into CL
    xor ch, ch      ; Zero out CH, so CX = length
    
draw_hline_loop:    ; Loop for 'length' times
    call printchar_buf ; Print the character in AL
    inc dl          ; Increment DL (move to next column)
    loop draw_hline_loop ; Decrement CX, loop if CX != 0
    
    pop dx          ; Restore DX
    pop cx          ; Restore CX
    ret             ; Return

draw_flower:        ; Procedure: Draw a 2-char flower
    ; Input: DH=row, DL=col
    push ax         ; Save AX
    push dx         ; Save DX
    mov al, '*'     ; AL = character '*'
    mov ah, 0x2E    ; AH = attribute (yellow on green)
    call printchar_buf ; Print
    inc dh          ; Move to next row
    mov al, '|'     ; AL = character '|'
    mov ah, 0x2A    ; AH = attribute (green on green)
    call printchar_buf ; Print
    pop dx          ; Restore original DX (row/col)
    pop ax          ; Restore original AX
    ret             ; Return

draw_bush_light:    ; Procedure: Draw a 2-char light bush
    ; Input: DH=row, DL=col
    push ax         ; Save AX
    push dx         ; Save DX
    mov al, 0xB0    ; AL = character 176 (light shade)
    mov ah, 0x2A    ; AH = attribute (green on green)
    call printchar_buf ; Print
    inc dl          ; Next column
    mov al, 0xB1    ; AL = character 177 (medium shade)
    mov ah, 0x2A    ; AH = attribute
    call printchar_buf ; Print
    pop dx          ; Restore DX
    pop ax          ; Restore AX
    ret             ; Return

draw_Bush:          ; Procedure: Draw a 2-char heavy bush
    ; Input: DH=row, DL=col
    push ax         ; Save AX
    push dx         ; Save DX
    mov al, 219     ; AL = character 219 (solid block)
    mov ah, 0x2a    ; AH = attribute (green on green)
    call printchar_buf ; Print
    inc dl          ; Next column
    mov al, 219     ; AL = character 219
    mov ah, 0x2a    ; AH = attribute
    call printchar_buf ; Print
    pop dx          ; Restore DX
    pop ax          ; Restore AX
    ret             ; Return

draw_flowerR:       ; Procedure: Draw a 2-char red flower
    ; Input: DH=row, DL=col
    push ax         ; Save AX
    push dx         ; Save DX
    mov al, '*'     ; AL = character '*'
    mov ah, 0x2c    ; AH = attribute (red on green)
    call printchar_buf ; Print
    inc dh          ; Next row
    mov al, '|'     ; AL = character '|'
    mov ah, 0x2A    ; AH = attribute (green on green)
    call printchar_buf ; Print
    pop dx          ; Restore DX
    pop ax          ; Restore AX
    ret             ; Return

draw_flowerM:       ; Procedure: Draw a 2-char magenta flower
    ; Input: DH=row, DL=col
    push ax         ; Save AX
    push dx         ; Save DX
    mov al, '*'     ; AL = character '*'
    mov ah, 0x25    ; AH = attribute (magenta on green)
    call printchar_buf ; Print
    inc dh          ; Next row
    mov al, '|'     ; AL = character '|'
    mov ah, 0x2A    ; AH = attribute (green on green)
    call printchar_buf ; Print
    pop dx          ; Restore DX
    pop ax          ; Restore AX
    ret             ; Return

draw_big_tree:      ; Procedure: Draw a multi-character tree
    ; Input: DH=row, DL=col (col is center of tree)
    push ax         ; Save AX
    push bx         ; Save BX
    push cx         ; Save CX
    push dx         ; Save DX

    ; Row 1 (top)
    mov al, 219     ; AL = solid block
    mov ah, 0x2A    ; AH = attribute (green on green)
    call printchar_buf ; Print

    ; Row 2 (3 blocks)
    inc dh          ; Next row
    dec dl          ; Move one col left
    mov al, 219     ; AL = solid block
    mov ah, 0x2A    ; AH = attribute
    call printchar_buf ; Print
    inc dl          ; Move to center
    call printchar_buf ; Print
    inc dl          ; Move one col right
    call printchar_buf ; Print
    dec dl          ; Reset to center col

    ; Row 3 (5 blocks)
    inc dh          ; Next row
    sub dl, 2       ; Move two cols left
    mov cx, 5       ; CX = counter for 5 blocks
draw_row3:
    mov al, 219     ; AL = solid block
    mov ah, 0x2A    ; AH = attribute
    call printchar_buf ; Print
    inc dl          ; Next col
    loop draw_row3  ; Loop 5 times
    sub dl, 3       ; Reset to center col (5 wide, so -2 -1 + 0 + 1 + 2 -> reset to 0, means sub (5-2)=3)
    inc dh          ; Next row
    sub dl, 2       ; Move two cols left
    mov cx, 5       ; CX = counter for 5 blocks

draw_row4:          ; Row 4 (5 blocks)
    mov al, 219     ; AL = solid block
    mov ah, 0x2A    ; AH = attribute
    call printchar_buf ; Print
    inc dl          ; Next col
    loop draw_row4  ; Loop 5 times
    sub dl, 3       ; Reset to center col

    ; Draw trunk (3 blocks)
    mov al, 219     ; AL = solid block
    mov ah, 0x26    ; AH = attribute (brown on green)
    inc dh          ; Next row
    call printchar_buf ; Print
    inc dh          ; Next row
    call printchar_buf ; Print
    inc dh          ; Next row
    call printchar_buf ; Print

    pop dx          ; Restore original DX
    pop cx          ; Restore original CX
    pop bx          ; Restore original BX
    pop ax          ; Restore original AX
    ret             ; Return

draw_landscape:     ; Procedure: Draw the green grassy areas and all decorations
    push ax         ; Save registers
    push bx
    push cx
    push dx

    mov dh, 0       ; DH = row 0
left_fill:          ; Loop: Fill the left green area
    mov dl, 0       ; DL = col 0
    mov bl, 25      ; BL = length 25
    mov al, 177     ; AL = character 177 (medium shade)
    mov ah, 0x22    ; AH = attribute (green on green, but darker)
    call draw_hline ; Draw the line
    inc dh          ; Next row
    cmp dh, 25      ; Compare row with 25
    jl left_fill    ; Jump if Less (if row < 25) to loop

    mov dh, 0       ; DH = row 0
right_fill:         ; Loop: Fill the right green area
    mov dl, 55      ; DL = col 55
    mov bl, 25      ; BL = length 25
    mov al, 177     ; AL = character 177
    mov ah, 0x22    ; AH = attribute (dark green)
    call draw_hline ; Draw the line
    inc dh          ; Next row
    cmp dh, 25      ; Compare row with 25
    jl right_fill   ; Jump if Less (if row < 25) to loop

    ; This section draws decorations based on the scrolled position
    ; (current_row + tree_offset) % 25 = decoration_type
    mov dh, 0       ; DH = row 0
left_decorations:   ; Loop: Draw left-side decorations
    push dx         ; Save current row (in DH)
    xor ah, ah      ; Zero out AH
    mov al, dh      ; Move current row into AL
    add ax, [tree_offset] ; Add the global tree_offset
    xor dx, dx      ; Clear DX for 32-bit division
    mov bx, 25      ; BX = 25 (our modulus)
    div bx          ; Divide AX by BX. Remainder is in DX
    mov bx, dx      ; Move the remainder into BX
    pop dx          ; Restore original DX (with current row)
    
    ; Check the remainder (in BX) to decide what to draw
    cmp bx, 1       ; Is (row + offset) % 25 == 1?
    jne left_dec_check2 ; Jump if Not Equal
    push dx         ; Save row
    mov dl, 5       ; Set col
    call draw_big_tree ; Draw
    pop dx          ; Restore row
    jmp left_dec_next ; Go to the next row

left_dec_check2:    ; Is remainder == 10?
    cmp bx, 10
    jne left_dec_check3
    push dx
    mov dl, 12
    call draw_big_tree
    pop dx
    jmp left_dec_next

left_dec_check3:    ; Is remainder == 5?
    cmp bx, 5
    jne left_dec_check4
    push dx
    mov dl, 18
    call draw_big_tree
    pop dx
    jmp left_dec_next

left_dec_check4:    ; Is remainder == 15?
    cmp bx, 15
    jne left_dec_check5
    push dx
    mov dl, 16
    call draw_big_tree
    pop dx
    jmp left_dec_next

left_dec_check5:    ; Is remainder == 18?
    cmp bx, 18
    jne left_dec_check6
    push dx
    mov dl, 4
    call draw_big_tree
    pop dx
    jmp left_dec_next

left_dec_check6:    ; Is remainder == 19?
    cmp bx, 19
    jne left_dec_check7
    push dx
    mov dl, 8
    call draw_flowerR ; Red flower
    pop dx
    jmp left_dec_next

left_dec_check7:    ; Is remainder == 11?
    cmp bx, 11
    jne left_dec_check8
    push dx
    mov dl, 4
    call draw_flowerR ; Red flower
    pop dx
    jmp left_dec_next

left_dec_check8:    ; Is remainder == 16?
    cmp bx, 16
    jne left_dec_check9
    push dx
    mov dl, 4
    call draw_flower ; Yellow flower
    pop dx
    jmp left_dec_next

left_dec_check9:    ; Is remainder == 22?
    cmp bx, 22
    jne left_dec_check10
    push dx
    mov dl, 23
    call draw_flowerM ; Magenta flower
    pop dx
    jmp left_dec_next

left_dec_check10:   ; Is remainder == 7?
    cmp bx, 7
    jne left_dec_check11
    push dx
    mov dl, 7
    call draw_flowerR ; Red flower
    pop dx
    jmp left_dec_next

left_dec_check11:   ; Is remainder == 4?
    cmp bx, 4
    jne left_dec_check12
    push dx
    mov dl, 9
    call draw_flowerM ; Magenta flower
    pop dx
    jmp left_dec_next

left_dec_check12:   ; Is remainder == 6?
    cmp bx, 6
    jne left_dec_check13
    push dx
    mov dl, 10
    call draw_flower ; Yellow flower
    pop dx
    jmp left_dec_next

left_dec_check13:   ; Is remainder == 23?
    cmp bx, 23
    jne left_dec_check14
    push dx
    mov dl, 14
    call draw_Bush ; Heavy bush
    pop dx
    jmp left_dec_next

left_dec_check14:   ; Is remainder == 2?
    cmp bx, 2
    jne left_dec_check15
    push dx
    mov dl, 12
    call draw_Bush ; Heavy bush
    pop dx
    jmp left_dec_next

left_dec_check15:   ; Is remainder == 5? (Note: duplicate check, but for different item)
    cmp bx, 5
    jne left_dec_check16
    push dx
    mov dl, 22
    call draw_bush_light ; Light bush
    pop dx
    jmp left_dec_next

left_dec_check16:   ; Is remainder == 14?
    cmp bx, 14
    jne left_dec_next
    push dx
    mov dl, 20
    call draw_bush_light ; Light bush
    pop dx

left_dec_next:      ; Label: End of checks for this row
    inc dh          ; Move to the next row
    cmp dh, 25      ; Compare row with 25
    jl left_decorations ; Loop if row < 25

    ; This is the same logic as above, but for the right side
    mov dh, 0       ; DH = row 0
right_decorations:  ; Loop: Draw right-side decorations
    push dx         ; Save current row
    xor ah, ah      ; Zero AH
    mov al, dh      ; AL = current row
    add ax, [tree_offset] ; Add global scroll offset
    xor dx, dx      ; Clear DX
    mov bx, 25      ; BX = modulus 25
    div bx          ; Divide AX by BX, remainder in DX
    mov bx, dx      ; Move remainder to BX
    pop dx          ; Restore original DX (with current row)
    
    cmp bx, 5       ; Is remainder == 5?
    jne right_dec_check2
    push dx
    mov dl, 60
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check2:   ; Is remainder == 1?
    cmp bx, 1
    jne right_dec_check3
    push dx
    mov dl, 70
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check3:   ; Is remainder == 12?
    cmp bx, 12
    jne right_dec_check4
    push dx
    mov dl, 70
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check4:   ; Is remainder == 8?
    cmp bx, 8
    jne right_dec_check5
    push dx
    mov dl, 76
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check5:   ; Is remainder == 18?
    cmp bx, 18
    jne right_dec_check6
    push dx
    mov dl, 76
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check6:   ; Is remainder == 16?
    cmp bx, 16
    jne right_dec_check7
    push dx
    mov dl, 60
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check7:   ; Is remainder == 17?
    cmp bx, 17
    jne right_dec_check8
    push dx
    mov dl, 65
    call draw_flowerM
    pop dx
    jmp right_dec_next

right_dec_check8:   ; Is remainder == 2?
    cmp bx, 2
    jne right_dec_check9
    push dx
    mov dl, 76
    call draw_flowerM
    pop dx
    jmp right_dec_next

right_dec_check9:   ; Is remainder == 12? (Note: duplicate check, but for different item)
    cmp bx, 12
    jne right_dec_check10
    push dx
    mov dl, 63
    call draw_flower
    pop dx
    jmp right_dec_next

right_dec_check10:  ; Is remainder == 23?
    cmp bx, 23
    jne right_dec_check11
    push dx
    mov dl, 79
    call draw_flowerR
    pop dx
    jmp right_dec_next

right_dec_check11:  ; Is remainder == 20?
    cmp bx, 20
    jne right_dec_check12
    push dx
    mov dl, 66
    call draw_flower
    pop dx
    jmp right_dec_next

right_dec_check12:  ; Is remainder == 10?
    cmp bx, 10
    jne right_dec_check13
    push dx
    mov dl, 67
    call draw_flowerR
    pop dx
    jmp right_dec_next

right_dec_check13:  ; Is remainder == 2? (Note: duplicate check)
    cmp bx, 2
    jne right_dec_check14
    push dx
    mov dl, 63
    call draw_flower
    pop dx
    jmp right_dec_next

right_dec_check14:  ; Is remainder == 9?
    cmp bx, 9
    jne right_dec_check15
    push dx
    mov dl, 70
    call draw_Bush
    pop dx
    jmp right_dec_next

right_dec_check15:  ; Is remainder == 23? (Note: duplicate check)
    cmp bx, 23
    jne right_dec_check16
    push dx
    mov dl, 70
    call draw_Bush
    pop dx
    jmp right_dec_next

right_dec_check16:  ; Is remainder == 24?
    cmp bx, 24
    jne right_dec_check17
    push dx
    mov dl, 62
    call draw_bush_light
    pop dx
    jmp right_dec_next

right_dec_check17:  ; Is remainder == 5? (Note: duplicate check)
    cmp bx, 5
    jne right_dec_next
    push dx
    mov dl, 74
    call draw_bush_light
    pop dx

right_dec_next:     ; Label: End of checks for this row
    inc dh          ; Next row
    cmp dh, 25      ; Compare row with 25
    jl right_decorations ; Loop if row < 25

    pop dx          ; Restore registers
    pop cx
    pop bx
    pop ax
    ret             ; Return

draw_road:          ; Procedure: Draw the road, curbs, and lane dividers
    push ax         ; Save registers
    push bx
    push cx
    push dx

    mov dh, 0       ; DH = row 0

road_loop:          ; Loop for each row (0-24)
    mov dl, 25      ; DL = column 25
    mov bl, 30      ; BL = length 30
    mov al, 176     ; AL = character 176 (light shade)
    mov ah, 0x08    ; AH = attribute (dark grey on black)
    call draw_hline ; Draw the road surface

    ; Draw left curb
    mov dl, 25      ; DL = col 25
    mov al, 219     ; AL = solid block
    mov ah, 0x0F    ; AH = attribute (bright white)
    call printchar_buf ; Print

    ; Draw right curb
    mov dl, 54      ; DL = col 54
    call printchar_buf ; Print (AL and AH are still set)

    ; Draw lane dividers based on scroll offset
    mov ax, [road_offset] ; Get the global road offset
    xor ah, ah      ; Zero AH
    add al, dh      ; Add the current row number
    mov bl, 3       ; BL = 3 (for the modulus)
    div bl          ; Divide AL by BL. Remainder is in AH
    cmp ah, 0       ; Compare remainder with 0
    jne skip_divider ; Jump if Not Equal (if (row + offset) % 3 != 0)

    ; If remainder is 0, draw the dividers
    mov dl, 35      ; DL = col 35 (left divider)
    mov al, 186     ; AL = character 186 (vertical double line)
    mov ah, 0x0F    ; AH = attribute (bright white)
    call printchar_buf ; Print

    mov dl, 44      ; DL = col 44 (right divider)
    mov al, 186     ; AL = character 186
    mov ah, 0x0F    ; AH = attribute
    call printchar_buf ; Print

skip_divider:       ; Label: Jump here if no divider is drawn
    inc dh          ; Next row
    cmp dh, 25      ; Compare row with 25
    jl road_loop    ; Loop if row < 25

    pop dx          ; Restore registers
    pop cx
    pop bx
    pop ax
    ret             ; Return

draw_player_car:    ; Procedure: Draw the player's car
    ; Input: [player_lane] variable (0, 1, or 2)
    push ax         ; Save registers
    push bx
    push dx
    
    xor bx, bx      ; Zero out BX
    mov bl, [player_lane] ; Load the player's lane into BL
    mov dl, 29      ; DL = default column (Lane 0)
    cmp bl, 1       ; Compare lane with 1 (Center)
    jne player_not_center ; Jump if Not Equal
    mov dl, 38      ; Set DL to column for Lane 1
    jmp player_got_col ; Jump to drawing
player_not_center:
    cmp bl, 2       ; Compare lane with 2 (Right)
    jne player_got_col ; Jump if Not Equal (already set for Lane 0)
    mov dl, 47      ; Set DL to column for Lane 2
player_got_col:

    ; Draw the car, char by char, relative to DL
    mov dh, 20      ; DH = row 20
    mov al, 219     ; AL = solid block
    mov ah, 0x0E    ; AH = attribute (yellow) - 'headlight'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x00    ; AH = attribute (black) - 'grill'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x00    ; AH = attribute (black) - 'grill'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x0E    ; AH = attribute (yellow) - 'headlight'
    call printchar_buf
    
    add dh, 1       ; Next row (row 21)
    sub dl, 3       ; Reset to starting col
    mov al, 219     ; AL = solid block
    mov ah, 0x0E    ; AH = attribute (yellow) - 'body'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x0B    ; AH = attribute (light cyan) - 'windshield'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x0B    ; AH = attribute (light cyan) - 'windshield'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x0E    ; AH = attribute (yellow) - 'body'
    call printchar_buf
    
    add dh, 1       ; Next row (row 22)
    sub dl, 3       ; Reset to starting col
    mov al, 220     ; AL = character 220 (bottom half block)
    mov ah, 0x0E    ; AH = attribute (yellow) - 'tire'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x00    ; AH = attribute (black) - 'under'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x00    ; AH = attribute (black) - 'under'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 220     ; AL = character 220
    mov ah, 0x0E    ; AH = attribute (yellow) - 'tire'
    call printchar_buf
    
    pop dx          ; Restore registers
    pop bx
    pop ax
    ret             ; Return

draw_other_car:     ; Procedure: Draw an enemy car
    ; Input: DH=row, BL=lane (0, 1, or 2)
    push ax         ; Save registers
    push bx
    push dx
    
    xor ax, ax      ; Zero out AX
    mov al, bl      ; Move BL (lane) into AL
    mov dl, 29      ; DL = default column (Lane 0)
    cmp al, 1       ; Compare lane with 1 (Center)
    jne other_not_center ; Jump if Not Equal
    mov dl, 38      ; Set DL to column for Lane 1
    jmp other_got_col ; Jump to drawing
other_not_center:
    cmp al, 2       ; Compare lane with 2 (Right)
    jne other_got_col ; Jump if Not Equal (already set for Lane 0)
    mov dl, 47      ; Set DL to column for Lane 2
other_got_col:

    ; Draw the car, char by char, relative to DL and DH
    mov al, 219     ; AL = solid block
    mov ah, 0x00    ; AH = attribute (black) - 'tire'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x0e    ; AH = attribute (yellow) - 'body'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x0e    ; AH = attribute (yellow) - 'body'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x00    ; AH = attribute (black) - 'tire'
    call printchar_buf
    
    add dh, 1       ; Next row
    sub dl, 3       ; Reset to starting col
    mov al, 219     ; AL = solid block
    mov ah, 0x0E    ; AH = attribute (yellow) - 'body'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x04    ; AH = attribute (red) - 'windshield'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x04    ; AH = attribute (red) - 'windshield'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x0E    ; AH = attribute (yellow) - 'body'
    call printchar_buf
    
    add dh, 1       ; Next row
    sub dl, 3       ; Reset to starting col
    mov al, 220     ; AL = character 220
    mov ah, 0x8E    ; AH = attribute (blinking yellow) - 'headlight'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x03    ; AH = attribute (cyan) - 'grill'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 219     ; AL = solid block
    mov ah, 0x03    ; AH = attribute (cyan) - 'grill'
    call printchar_buf
    
    add dl, 1       ; Next col
    mov al, 220     ; AL = character 220
    mov ah, 0x8E    ; AH = attribute (blinking yellow) - 'headlight'
    call printchar_buf
    
    pop dx          ; Restore registers
    pop bx
    pop ax
    ret             ; Return

draw_coin:          ; Procedure: Draw a coin
    ; Input: DH=row, BL=lane (0, 1, or 2)
    push ax         ; Save AX
    push dx         ; Save DX
    
    xor ax, ax      ; Zero out AX
    mov al, bl      ; Move BL (lane) into AL
    mov dl, 30      ; DL = default column (Lane 0) + 1
    cmp al, 1       ; Compare lane with 1 (Center)
    jne coin_not_center ; Jump if Not Equal
    mov dl, 39      ; Set DL to column for Lane 1 + 1
    jmp coin_got_col ; Jump to drawing
coin_not_center:
    cmp al, 2       ; Compare lane with 2 (Right)
    jne coin_got_col ; Jump if Not Equal
    mov dl, 48      ; Set DL to column for Lane 2 + 1
coin_got_col:

    inc dl          ; Move one more column right (to center it in the 4-wide car space)
    mov al, 254     ; AL = character 254 (small square)
    mov ah, 0x0E    ; AH = attribute (yellow)
    call printchar_buf ; Print the coin
    
    pop dx          ; Restore DX
    pop ax          ; Restore AX
    ret             ; Return

update_objects:     ; Procedure: Update positions of all active cars and coins
    push ax         ; Save registers
    push cx
    push si
    
    mov si, car1    ; SI = address of first car structure
    mov cx, 4       ; CX = 4 (number of cars)
car_loop:
    cmp byte [si+2], 0 ; Check the active_flag (byte 2) of the car
    je car_next     ; Jump if Equal (if flag=0, car is inactive) to 'car_next'
    
    mov al, [si]    ; Load the car's row (byte 0) into AL
    inc al          ; Increment the row (move car down the screen)
    cmp al, 24      ; Compare row with 24
    jl car_ok       ; Jump if Less (if row < 24) to keep it active
    mov byte [si+2], 0 ; If row >= 24, set active_flag to 0 (deactivate)
    jmp car_next    ; Go to next car
car_ok:
    mov [si], al    ; Save the new row back into the structure
car_next:
    add si, 3       ; Move SI to the next car structure (3 bytes per car)
    loop car_loop   ; Decrement CX, loop if CX != 0
    
    mov si, coin1   ; SI = address of first coin structure
    mov cx, 3       ; CX = 3 (number of coins)
coin_loop:
    cmp byte [si+2], 0 ; Check the active_flag (byte 2)
    je coin_next    ; Jump if Equal (if flag=0, coin is inactive)
    
    mov al, [si]    ; Load the coin's row (byte 0) into AL
    inc al          ; Increment the row (move coin down the screen)
    cmp al, 24      ; Compare row with 24
    jl coin_ok      ; Jump if Less (if row < 24)
    mov byte [si+2], 0 ; If row >= 24, deactivate it
    jmp coin_next   ; Go to next coin
coin_ok:
    mov [si], al    ; Save the new row
coin_next:
    add si, 3       ; Move SI to the next coin structure (3 bytes per coin)
    loop coin_loop  ; Decrement CX, loop if CX != 0
    
    pop si          ; Restore registers
    pop cx
    pop ax
    ret             ; Return

spawn_car:          ; Procedure: Randomly try to spawn a new car
    push ax         ; Save registers
    push bx
    push cx
    push dx
    push si
    
    call get_random ; Get a random number in AX
    and ax, 0x003F  ; AND AX with 63 (00111111b). Gives a 1-in-64 chance (approx)
    cmp ax, 3       ; Compare result with 3
    jg no_spawn_car ; Jump if Greater (if > 3), so don't spawn. (Gives 4/64 = 1/16 chance per frame)
    
    ; If we spawn, find an inactive car slot
    mov si, car1    ; SI = address of first car
    mov cx, 4       ; CX = 4 (number of cars)
find_car:
    cmp byte [si+2], 0 ; Check active_flag
    je found_car    ; Jump if Equal (if flag=0, we found a free slot)
    add si, 3       ; Move to next car structure
    loop find_car   ; Loop
    jmp no_spawn_car ; If loop finishes, all 4 slots are active. Don't spawn.

found_car:          ; Label: We found an inactive slot at [SI]
    mov byte [si], 0 ; Set car's row (byte 0) to 0 (top of screen)
    call get_random ; Get another random number
    xor dx, dx      ; Clear DX for division
    mov bx, 3       ; BX = 3 (for 3 lanes)
    div bx          ; Divide AX by BX. Remainder (0, 1, or 2) is in DX
    mov [si+1], dl  ; Store the random lane (from DL) into car's lane (byte 1)
    mov byte [si+2], 1 ; Set active_flag (byte 2) to 1 (active)

no_spawn_car:       ; Label: Exit point
    pop si          ; Restore registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret             ; Return

spawn_coin:         ; Procedure: Randomly try to spawn a new coin
    push ax         ; Save registers
    push bx
    push cx
    push dx
    push si
    
    call get_random ; Get random number in AX
    and ax, 0x00FF  ; AND AX with 255.
    cmp ax, 3       ; Compare result with 3
    jg no_spawn_coin ; Jump if Greater (if > 3). (Gives 4/256 = 1/64 chance per frame)
    
    ; If we spawn, find an inactive coin slot
    mov si, coin1   ; SI = address of first coin
    mov cx, 3       ; CX = 3 (number of coins)
find_coin:
    cmp byte [si+2], 0 ; Check active_flag
    je found_coin   ; Jump if Equal (if flag=0, found free slot)
    add si, 3       ; Move to next coin structure
    loop find_coin  ; Loop
    jmp no_spawn_coin ; If loop finishes, all slots are active. Don't spawn.

found_coin:         ; Label: We found an inactive slot at [SI]
    mov byte [si], 0 ; Set coin's row (byte 0) to 0
    call get_random ; Get another random number
    xor dx, dx      ; Clear DX
    mov bx, 3       ; BX = 3 (for 3 lanes)
    div bx          ; Divide AX by BX. Remainder (0, 1, or 2) is in DX
    mov [si+1], dl  ; Store random lane into coin's lane (byte 1)
    mov byte [si+2], 1 ; Set active_flag (byte 2) to 1

no_spawn_coin:      ; Label: Exit point
    pop si          ; Restore registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret             ; Return

check_collisions:   ; Procedure: Check if the player has hit any active cars
    push ax         ; Save registers
    push bx
    push cx
    push si
    
    xor bx, bx      ; Zero out BX
    mov bl, [player_lane] ; Load the player's lane into BL
    
    mov si, car1    ; SI = address of first car
    mov cx, 4       ; CX = 4 (number of cars)
collision_loop:
    cmp byte [si+2], 0 ; Check active_flag
    je collision_next ; Jump if Equal (if inactive) to skip this car
    
    ; Check row collision
    xor ax, ax      ; Zero out AX
    mov al, [si]    ; Load car's row into AL
    cmp ax, 17      ; Compare car row with 17 (player's car is at 20-22)
    jl collision_next ; Jump if Less (car is above player)
    cmp ax, 23      ; Compare car row with 23
    jg collision_next ; Jump if Greater (car is below player)
    
    ; If we are here, rows are overlapping. Check lane collision.
    xor ax, ax      ; Zero out AX
    mov al, [si+1]  ; Load car's lane into AL
    cmp ax, bx      ; Compare car's lane with player's lane (in BX)
    jne collision_next ; Jump if Not Equal (no collision)
    
    ; If we are here, lanes AND rows match. Collision!
    mov byte [game_over], 1 ; Set the game_over flag to 1

collision_next:     ; Label: Check next car
    add si, 3       ; Move to next car structure
    loop collision_loop ; Loop
    
    pop si          ; Restore registers
    pop cx
    pop bx
    pop ax
    ret             ; Return

check_coins:        ; Procedure: Check if the player has collected any coins
    push ax         ; Save registers
    push bx
    push cx
    push si
    
    xor bx, bx      ; Zero out BX
    mov bl, [player_lane] ; Load player's lane into BL
    
    mov si, coin1   ; SI = address of first coin
    mov cx, 3       ; CX = 3 (number of coins)
coin_check_loop:
    cmp byte [si+2], 0 ; Check active_flag
    je coin_check_next ; Jump if Equal (if inactive) to skip
    
    ; Check row collision (coin is 1 char, player is 3)
    xor ax, ax      ; Zero out AX
    mov al, [si]    ; Load coin's row into AL
    cmp ax, 19      ; Compare coin row with 19 (player's car is at 20-22)
    jl coin_check_next ; Jump if Less (coin is above player)
    cmp ax, 23      ; Compare coin row with 23
    jg coin_check_next ; Jump if Greater (coin is below player)
    
    ; If rows overlap, check lane
    xor ax, ax      ; Zero out AX
    mov al, [si+1]  ; Load coin's lane into AL
    cmp ax, bx      ; Compare coin's lane with player's lane
    jne coin_check_next ; Jump if Not Equal (no collection)
    
    ; If we are here, lanes AND rows match. Coin collected!
    mov byte [si+2], 0 ; Deactivate the coin (set active_flag to 0)
    mov ax, [score] ; Load the current score into AX
    add ax, 5       ; Add 5 points
    mov [score], ax ; Save the new score

coin_check_next:    ; Label: Check next coin
    add si, 3       ; Move to next coin structure
    loop coin_check_loop ; Loop
    
    pop si          ; Restore registers
    pop cx
    pop bx
    pop ax
    ret             ; Return

draw_all_cars:      ; Procedure: Loop through all cars and draw active ones
    push cx         ; Save registers
    push dx
    push si
    
    mov si, car1    ; SI = address of first car
    mov cx, 4       ; CX = 4 (number of cars)
draw_cars_loop:
    cmp byte [si+2], 0 ; Check active_flag
    je draw_cars_next ; Jump if Equal (if inactive) to skip
    
    mov dh, [si]    ; Load car's row into DH
    mov bl, [si+1]  ; Load car's lane into BL
    call draw_other_car ; Call procedure to draw it

draw_cars_next:     ; Label: Check next car
    add si, 3       ; Move to next car structure
    loop draw_cars_loop ; Loop
    
    pop si          ; Restore registers
    pop dx
    pop cx
    ret             ; Return

draw_all_coins:     ; Procedure: Loop through all coins and draw active ones
    push cx         ; Save registers
    push dx
    push si
    
    mov si, coin1   ; SI = address of first coin
    mov cx, 3       ; CX = 3 (number of coins)
draw_coins_loop:
    cmp byte [si+2], 0 ; Check active_flag
    je draw_coins_next ; Jump if Equal (if inactive) to skip
    
    mov dh, [si]    ; Load coin's row into DH
    mov bl, [si+1]  ; Load coin's lane into BL
    call draw_coin  ; Call procedure to draw it

draw_coins_next:    ; Label: Check next coin
    add si, 3       ; Move to next coin structure
    loop draw_coins_loop ; Loop
    
    pop si          ; Restore registers
    pop dx
    pop cx
    ret             ; Return

draw_score:         ; Procedure: Draw the score on the HUD
    push ax         ; Save registers
    push bx
    push cx
    push dx
    
    ; Print the "Score:" label
    mov dh, 0       ; DH = row 0
    mov dl, 63      ; DL = col 63
    mov ah, 0x0F    ; AH = attribute (bright white)
	
	mov al, ' '
    call printchar_buf
	inc dl
    mov al, 'S'     ; AL = 'S'
    call printchar_buf ; Print
    inc dl          ; Next col
    mov al, 'c'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, ':'
    call printchar_buf
    
    ; Convert the 16-bit score to decimal digits
    mov ax, [score] ; Load score into AX
    mov bx, 10      ; BX = 10 (our divisor)
    xor cx, cx      ; Zero out CX (this will count the number of digits)

    cmp ax, 0       ; Compare score with 0
    jne convert_score ; Jump if Not Equal (if score > 0)
    
    ; If score is 0, just push '0'
    push 0          ; Push a 0 onto the stack
    inc cx          ; Increment digit counter to 1
    jmp print_setup ; Jump to printing

convert_score:      ; Loop: Convert score to digits
    xor dx, dx      ; Clear DX (required for 16-bit division)
    div bx          ; Divide DX:AX by BX (10). Quotient in AX, Remainder in DX
    push dx         ; Push the remainder (a digit 0-9) onto the stack
    inc cx          ; Increment the digit counter
    test ax, ax     ; Check if quotient (in AX) is zero
    jnz convert_score ; Jump if Not Zero (if AX > 0) to continue loop

print_setup:        ; Label: Set up for printing digits
    mov dh, 0       ; DH = row 0
    mov dl, 70      ; DL = col 70 (after "Score:")

print_score:        ; Loop: Print the digits (by popping them from the stack)
    pop bx          ; Pop a digit (0-9) into BX
    mov al, bl      ; Move the digit into AL
    add al, '0'     ; Add '0' (ASCII 48) to convert 0-9 to '0'-'9'
    mov ah, 0x0F    ; AH = attribute (bright white)
    push cx         ; Save CX (loop counter)
    push dx         ; Save DX (row/col)
    call printchar_buf ; Print the digit
	inc dl
	mov al, ' '
    call printchar_buf
    pop dx          ; Restore DX
    pop cx          ; Restore CX
    inc dl          ; Move to next column
    loop print_score ; Decrement CX, loop if CX != 0

    pop dx          ; Restore original registers
    pop cx
    pop bx
    pop ax
    ret             ; Return

draw_box_buf:       ; Procedure: Draw a box in the buffer
    ; Input: AH=attr, DH=top, DL=left, BH=height, BL=width
    push ax         ; Save registers
    push bx
    push cx
    push dx
    push si
    
    mov si, dx      ; Save original DH:DL (top-left corner) in SI
    
    ; Draw top-left corner
    mov al, 201     ; AL = character 201 (top-left corner)
    call printchar_buf ; Print
    
    ; Draw top edge
    mov cl, bl      ; Load CL with width (from BL)
    dec cl          ; Decrement
    dec cl          ; Decrement (to account for two corners)
draw_top_buf:
    inc dl          ; Next col
    mov al, 205     ; AL = character 205 (horizontal line)
    call printchar_buf ; Print
    dec cl          ; Decrement width counter
    jnz draw_top_buf ; Jump if Not Zero
    
    ; Draw top-right corner
    inc dl          ; Next col
    mov al, 187     ; AL = character 187 (top-right corner)
    call printchar_buf ; Print
    
    ; Draw sides
    mov dx, si      ; Restore original top-left corner to DX
    mov cl, bh      ; Load CL with height (from BH)
    dec cl          ; Decrement
    dec cl          ; Decrement (to account for top/bottom edges)
    inc dh          ; Move to next row
draw_sides_buf:
    push dx         ; Save current row/col
    mov al, 186     ; AL = character 186 (vertical line)
    call printchar_buf ; Print left side
    add dl, bl      ; Add width (from BL) to DL
    dec dl          ; Decrement (to get to the right edge column)
    call printchar_buf ; Print right side
    pop dx          ; Restore original row/col for this iteration
    inc dh          ; Move to next row
    dec cl          ; Decrement height counter
    jnz draw_sides_buf ; Jump if Not Zero
    
    ; Draw bottom-left corner
    mov dx, si      ; Restore original top-left corner
    add dh, bh      ; Add height (from BH) to DH
    dec dh          ; Decrement (to get to the bottom row)
    mov al, 200     ; AL = character 200 (bottom-left corner)
    call printchar_buf ; Print
    
    ; Draw bottom edge
    mov cl, bl      ; Load CL with width (from BL)
    dec cl          ; Decrement
    dec cl          ; Decrement (for corners)
draw_bottom_buf:
    inc dl          ; Next col
    mov al, 205     ; AL = character 205 (horizontal line)
    call printchar_buf ; Print
    dec cl          ; Decrement width counter
    jnz draw_bottom_buf ; Jump if Not Zero
    
    ; Draw bottom-right corner
    inc dl          ; Next col
    mov al, 188     ; AL = character 188 (bottom-right corner)
    call printchar_buf ; Print
    
    pop si          ; Restore registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret             ; Return

show_game_over_popup: ; Procedure: Draw the "Game Over" message box
    push ax         ; Save registers
    push bx
    push cx
    push dx
    push si
    
    ; Draw the box
    mov dh, 8       ; top row 8
    mov dl, 20      ; left col 20
    mov bl, 40      ; width 40
    mov bh, 10      ; height 10
    mov ah, 0x4F    ; attribute (bright white on red)
    call draw_box_buf
    
    ; Fill the box with the background color
    mov dh, 9       ; start row 9
popup_fill_loop:
    mov dl, 21      ; start col 21
    mov cx, 38      ; width 38
popup_fill_row:
    mov al, ' '     ; AL = space
    mov ah, 0x4F    ; attribute (bright white on red)
    call printchar_buf
    inc dl          ; next col
    loop popup_fill_row ; loop for row
    inc dh          ; next row
    cmp dh, 17      ; compare with bottom row
    jl popup_fill_loop ; loop for all rows
    
    ; Print "GAME OVER!"
    mov dh, 10      ; row 10
    mov dl, 34      ; col 34
    mov ah, 0x4E    ; attribute (yellow on red)
    mov al, 'G'
    call printchar_buf
    inc dl
    mov al, 'A'
    call printchar_buf
    inc dl
    mov al, 'M'
    call printchar_buf
    inc dl
    mov al, 'E'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'O'
    call printchar_buf
    inc dl
    mov al, 'V'
    call printchar_buf
    inc dl
    mov al, 'E'
    call printchar_buf
    inc dl
    mov al, 'R'
    call printchar_buf
    inc dl
    mov al, '!'
    call printchar_buf
    
    ; Print "Final Score: "
    mov dh, 12      ; row 12
    mov dl, 32      ; col 32
    mov ah, 0x4F    ; attribute (white on red)
    mov al, 'F'
    call printchar_buf
    inc dl
    mov al, 'i'
    call printchar_buf
    inc dl
    mov al, 'n'
    call printchar_buf
    inc dl
    mov al, 'a'
    call printchar_buf
    inc dl
    mov al, 'l'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'S'
    call printchar_buf
    inc dl
    mov al, 'c'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, ':'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    
    inc dl          ; next col
    mov si, dx      ; Save the print position (DH:DL) in SI
    
    ; Convert and print the final score
    mov ax, [score] ; Load score into AX
    mov bx, 10      ; BX = 10
    xor cx, cx      ; CX = digit counter
    
    cmp ax, 0       ; Compare score with 0
    jne convert_popup_score ; Jump if not 0
    
    ; If score is 0, just print '0'
    mov al, '0'
    mov ah, 0x4F    ; attribute
    mov dx, si      ; Restore print position
    call printchar_buf
    jmp after_popup_score ; Skip conversion

convert_popup_score: ; Loop to convert score to digits
    xor dx, dx      ; Clear DX
    div bx          ; Divide DX:AX by 10. Quotient in AX, Remainder in DX
    push dx         ; Push remainder (digit)
    inc cx          ; Increment digit counter
    test ax, ax     ; Check if quotient is 0
    jnz convert_popup_score ; Loop if not 0

print_popup_score_setup:
    mov dx, si      ; Restore print position (DH:DL)

print_popup_score:  ; Loop to print digits
    pop ax          ; Pop digit into AX
    add al, '0'     ; Convert to ASCII
    mov ah, 0x4F    ; attribute
    call printchar_buf ; Print
    inc dl          ; next col
    loop print_popup_score

after_popup_score:  ; Label: After score is printed
    
    ; Print "Press P to Play Again"
    mov dh, 14      ; row 14
    mov dl, 28      ; col 28
    mov ah, 0x4F    ; attribute (white on red)
    mov al, 'P'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov ah, 0x4A    ; attribute (green on red)
    mov al, 'P'
    call printchar_buf
    inc dl
    mov ah, 0x4F    ; attribute (white on red)
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'P'
    call printchar_buf
    inc dl
    mov al, 'l'
    call printchar_buf
    inc dl
    mov al, 'a'
    call printchar_buf
    inc dl
    mov al, 'y'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'A'
    call printchar_buf
    inc dl
    mov al, 'g'
    call printchar_buf
    inc dl
    mov al, 'a'
    call printchar_buf
    inc dl
    mov al, 'i'
    call printchar_buf
    inc dl
    mov al, 'n'
    call printchar_buf
    
    ; Print "Press S to go to Main Menu"
    mov dh, 15      ; row 15
    mov dl, 26      ; col 26
    mov ah, 0x4F    ; attribute (white on red)
    mov al, 'P'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov ah, 0x4C    ; attribute (light red on red) - 'S'
    mov al, 'S'
    call printchar_buf
    inc dl
    mov ah, 0x4F    ; attribute (white on red)
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'g'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'M'
    call printchar_buf
    inc dl
    mov al, 'a'
    call printchar_buf
    inc dl
    mov al, 'i'
    call printchar_buf
    inc dl
    mov al, 'n'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'M'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, 'n'
    call printchar_buf
    inc dl
    mov al, 'u'
    call printchar_buf
    
    pop si          ; Restore registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret             ; Return

reset_game:         ; Procedure: Reset all game variables to their default state
    push ax         ; Save registers
    push cx
    push si
    
    mov word [score], 0 ; Reset score to 0
    mov word [frame_counter], 0 ; Reset frame counter
    mov byte [game_over], 0 ; Clear game over flag
    mov byte [player_lane], 1 ; Reset player to center lane
    mov word [road_offset], 0 ; Reset road scroll
    mov word [tree_offset], 0 ; Reset tree scroll
    mov byte [esc_pressed], 0 ; Clear ESC flag
    mov byte [game_paused], 0 ; Clear pause flag
    
    ; Deactivate all cars
    mov si, car1    ; SI = address of first car
    mov cx, 4       ; CX = 4 cars
clear_cars:
    mov byte [si], 0   ; row = 0
    mov byte [si+1], 0 ; lane = 0
    mov byte [si+2], 0 ; active_flag = 0
    add si, 3       ; next car structure
    loop clear_cars
    
    ; Deactivate all coins
    mov si, coin1   ; SI = address of first coin
    mov cx, 3       ; CX = 3 coins
clear_coins:
    mov byte [si], 0   ; row = 0
    mov byte [si+1], 0 ; lane = 0
    mov byte [si+2], 0 ; active_flag = 0
    add si, 3       ; next coin structure
    loop clear_coins
    
    pop si          ; Restore registers
    pop cx
    pop ax
    ret             ; Return

keyboard_isr:       ; Procedure: Custom Keyboard Interrupt Service Routine
    push ax         ; Save all registers
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    
    mov ax, cs      ; Load Code Segment into AX
    mov ds, ax      ; Set DS to CS (so we can access our variables)
    
    in al, 0x60     ; Read the keyboard scan code from port 0x60
    
    cmp al, 0x01    ; Compare scan code with 0x01 (ESC key press)
    jne keyboard_isr_chain ; Jump if Not Equal (if not ESC)
    
    ; If it was ESC
    mov byte [cs:esc_pressed], 1 ; Set our 'esc_pressed' flag
    
    mov al, 0x20    ; Load AL with 0x20 (End of Interrupt signal)
    out 0x20, al    ; Send EOI to the PIC (Programmable Interrupt Controller)
    
    pop es          ; Restore all registers
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret            ; Interrupt Return (do NOT chain to old ISR)

keyboard_isr_chain: ; Label: If key was not ESC
    mov al, 0x20    ; Load EOI signal
    out 0x20, al    ; Send EOI to the PIC
    
    pop es          ; Restore all registers
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    jmp far [cs:old_keyboard_isr] ; Jump to the original keyboard ISR (chaining)

timer_isr:          ; Procedure: Custom Timer Interrupt Service Routine (runs ~18.2 times/sec)
    push ax         ; Save all registers
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    
    mov ax, cs      ; Load Code Segment into AX
    mov ds, ax      ; Set DS to CS (to access our variables)
    
    ; Only scroll if game is active (not paused, not game over)
    cmp byte [game_paused], 1 ; Check if paused
    je timer_skip_scroll ; Jump if Equal (if paused)
    cmp byte [game_over], 1 ; Check if game over
    je timer_skip_scroll ; Jump if Equal (if game over)
    
    ; Update road offset for scrolling
    mov ax, [road_offset] ; Load current road offset
    dec ax          ; Decrement it
    cmp ax, 0       ; Compare with 0
    jge timer_road_ok ; Jump if Greater or Equal (if not negative)
    mov ax, 2       ; If negative, wrap around to 2 (for 3-pixel divider)
timer_road_ok:
    mov [road_offset], ax ; Save new offset
    
    ; Update tree offset for scrolling
    mov ax, [tree_offset] ; Load current tree offset
    dec ax          ; Decrement it
    cmp ax, 0       ; Compare with 0
    jge timer_tree_ok ; Jump if Greater or Equal
    mov ax, 24      ; If negative, wrap around to 24 (for 25-row modulus)
timer_tree_ok:
    mov [tree_offset], ax ; Save new offset

timer_skip_scroll:  ; Label: Jump here if game is paused
    ; Send EOI to PIC
    mov al, 0x20    ; Load 0x20 (End of Interrupt signal)
    out 0x20, al    ; Send EOI to the PIC
    
    pop es          ; Restore all registers
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    
    ; Chain to old timer ISR
    jmp far [cs:old_timer_isr] ; Jump to the original timer ISR

show_exit_confirmation: ; Procedure: Draw the "Are you sure?" pause menu
    push ax         ; Save registers
    push bx
    push cx
    push dx
    push si
    
    ; Draw the box
    mov dh, 9       ; top row 9
    mov dl, 15      ; left col 15
    mov bl, 50      ; width 50
    mov bh, 10      ; height 10
    mov ah, 0x4F    ; attribute (bright white on red)
    call draw_box_buf
    
    ; Fill the box
    mov dh, 10      ; start row 10
popup_exit_fill:
    mov dl, 16      ; start col 16
    mov cx, 48      ; width 48
popup_exit_row:
    mov al, ' '     ; AL = space
    mov ah, 0x4F    ; attribute
    call printchar_buf
    inc dl          ; next col
    loop popup_exit_row ; loop for row
    inc dh          ; next row
    cmp dh, 18      ; compare with bottom
    jl popup_exit_fill ; loop for all rows
    
    ; Print "Are you sure you want"
    mov dh, 11      ; row 11
    mov dl, 27      ; col 27
    mov ah, 0x4E    ; attribute (yellow on red)
    mov al, 'A'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'y'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, 'u'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, 'u'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'y'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, 'u'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'w'
    call printchar_buf
    inc dl
    mov al, 'a'
    call printchar_buf
    inc dl
    mov al, 'n'
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    
    ; Print "to exit the game?"
    mov dh, 12      ; row 12
    mov dl, 32      ; col 32
    mov ah, 0x4E    ; attribute
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, 'x'
    call printchar_buf
    inc dl
    mov al, 'i'
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'h'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'g'
    call printchar_buf
    inc dl
    mov al, 'a'
    call printchar_buf
    inc dl
    mov al, 'm'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, '?'
    call printchar_buf
    
    ; Print "Your Score: "
    mov dh, 14      ; row 14
    mov dl, 32      ; col 32
    mov ah, 0x4F    ; attribute (white on red)
    mov al, 'Y'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, 'u'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'S'
    call printchar_buf
    inc dl
    mov al, 'c'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, ':'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    
    inc dl          ; next col
    mov si, dx      ; Save print position in SI
    
    ; Convert and print current score
    mov ax, [score] ; Load score
    mov bx, 10      ; Divisor
    xor cx, cx      ; Digit counter
    
    cmp ax, 0       ; Check if score is 0
    jne convert_exit_score
    
    ; If score is 0
    mov al, '0'
    mov ah, 0x4F
    mov dx, si      ; Restore print position
    call printchar_buf
    jmp after_exit_score

convert_exit_score: ; Loop to convert score
    xor dx, dx      ; Clear DX
    div bx          ; Divide DX:AX by 10. Remainder in DX
    push dx         ; Push digit
    inc cx          ; Increment counter
    test ax, ax     ; Check if quotient is 0
    jnz convert_exit_score ; Loop if not 0

print_exit_score_setup:
    mov dx, si      ; Restore print position

print_exit_score:   ; Loop to print digits
    pop ax          ; Pop digit into AX
    add al, '0'     ; Convert to ASCII
    mov ah, 0x4F    ; attribute
    call printchar_buf
    inc dl          ; next col
    loop print_exit_score

after_exit_score:
    
    ; Print "Press P to Continue or S to Exit GAME"
    mov dh, 16      ; row 16
    mov dl, 21      ; col 21
    mov ah, 0x4F    ; attribute
    mov al, 'P'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov ah, 0x4A    ; attribute (green on red)
    mov al, 'P'
    call printchar_buf
    inc dl
    mov ah, 0x4F    ; attribute
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'C'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, 'n'
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'i'
    call printchar_buf
    inc dl
    mov al, 'n'
    call printchar_buf
    inc dl
    mov al, 'u'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov ah, 0x4C    ; attribute (light red on red)
    mov al, 'S'
    call printchar_buf
    inc dl
    mov ah, 0x4F    ; attribute
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'E'
    call printchar_buf
    inc dl
    mov al, 'x'
    call printchar_buf
    inc dl
    mov al, 'i'
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'G'
    call printchar_buf
    inc dl
    mov al, 'A'
    call printchar_buf
    inc dl
    mov al, 'M'
    call printchar_buf
    inc dl
    mov al, 'E'
    call printchar_buf
    
    ; Print "Press N to go to Main Menu"
    mov dh, 17      ; row 17
    mov dl, 26      ; col 26
    mov ah, 0x4F    ; attribute
    mov al, 'P'
    call printchar_buf
    inc dl
    mov al, 'r'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, 's'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov ah, 0x4A    ; attribute (green on red)
    mov al, 'N'
    call printchar_buf
    inc dl
    mov ah, 0x4F    ; attribute
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'g'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 't'
    call printchar_buf
    inc dl
    mov al, 'o'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'M'
    call printchar_buf
    inc dl
    mov al, 'a'
    call printchar_buf
    inc dl
    mov al, 'i'
    call printchar_buf
    inc dl
    mov al, 'n'
    call printchar_buf
    inc dl
    mov al, ' '
    call printchar_buf
    inc dl
    mov al, 'M'
    call printchar_buf
    inc dl
    mov al, 'e'
    call printchar_buf
    inc dl
    mov al, 'n'
    call printchar_buf
    inc dl
    mov al, 'u'
    call printchar_buf
    
    pop si          ; Restore registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret             ; Return

start:              ; Main program entry point (after variables)
    mov ax, 0x0003  ; AH=0x00 (Set Video Mode), AL=0x03 (80x25 16-color text mode)
    int 0x10        ; Call BIOS video interrupt
    
    ; Seed the random number generator
    mov ah, 0x00    ; AH=0x00 (Get System Time function)
    int 0x1A        ; Call BIOS time interrupt. Tick count is in CX:DX
    mov [random_seed], dx ; Use the lower 16-bits of the tick count (in DX) as our seed
    
    ; Save the original keyboard ISR (INT 9)
    xor ax, ax      ; Zero out AX
    mov es, ax      ; Set ES to 0 (to access the Interrupt Vector Table at 0000:xxxx)
    mov ax, [es:9*4] ; Get the offset of the original ISR from the IVT (vector 9 * 4 bytes/vector)
    mov [old_keyboard_isr], ax ; Save the offset
    mov ax, [es:9*4+2] ; Get the segment of the original ISR
    mov [old_keyboard_isr+2], ax ; Save the segment
    
    ; Hook our new keyboard ISR
    cli             ; Clear Interrupt Flag (disable interrupts) while we modify the IVT
    mov word [es:9*4], keyboard_isr ; Set the offset of our new ISR
    mov [es:9*4+2], cs ; Set the segment to our Code Segment (CS)
    
    ; Save the original timer ISR (INT 8)
    mov ax, [es:8*4] ; Get the offset of the original ISR
    mov [old_timer_isr], ax ; Save the offset
    mov ax, [es:8*4+2] ; Get the segment of the original ISR
    mov [old_timer_isr+2], ax ; Save the segment
    
    ; Hook our new timer ISR
    mov word [es:8*4], timer_isr ; Set the offset of our new ISR
    mov [es:8*4+2], cs ; Set the segment to our Code Segment
    sti             ; Set Interrupt Flag (re-enable interrupts)

main_menu_start:    ; Label: The start of the main menu
    call show_main_menu ; Display the main menu and wait for 'P' or 'ESC'
    call clrscr     ; Clear the physical screen (not the buffer) before starting game

game_loop:          ; The main game update loop
    cmp byte [esc_pressed], 1 ; Check if the ESC key flag (from the ISR) is set to 1
    je handle_esc_press ; Jump if Equal (if ESC was pressed) to the pause menu
    
    ; Check for user input (left/right arrows)
    mov ah, 0x01    ; AH=0x01 (Check for keypress status)
    int 0x16        ; Call BIOS keyboard interrupt
    jz no_key       ; Jump if Zero (if no key is in the buffer) to 'no_key'
    
    ; If a key is present, get it
    mov ah, 0x00    ; AH=0x00 (Get keypress)
    int 0x16        ; Call BIOS keyboard interrupt. Scan code in AH, ASCII in AL
    
    cmp ah, 0x4B    ; Compare AH (scan code) with 0x4B (Left Arrow)
    je move_left    ; Jump if Equal to 'move_left'
    cmp ah, 0x4D    ; Compare AH (scan code) with 0x4D (Right Arrow)
    je move_right   ; Jump if Equal to 'move_right'
    
    jmp no_key      ; If it wasn't left or right, ignore it

handle_esc_press:   ; Label: Called when ESC flag is set
    mov byte [game_paused], 1 ; Set the game_paused flag to 1
    
    ; Re-draw the current scene (so it's visible behind the popup)
    call clrbuffer  ; Clear the buffer
    call draw_landscape ; Draw landscape
    call draw_road  ; Draw road
    call draw_all_cars ; Draw cars
    call draw_all_coins ; Draw coins
    call draw_player_car ; Draw player
    call draw_score ; Draw score
    call show_exit_confirmation ; Draw the "Are you sure?" popup
    call flip_buffer ; Copy the buffer to the screen

flush_esc_key:      ; Loop: Clear any extra keys from the keyboard buffer
    mov ah, 0x01    ; AH=0x01 (Check status)
    int 0x16        ; Call keyboard interrupt
    jz wait_esc_response ; Jump if Zero (buffer is empty)
    
    mov ah, 0x00    ; AH=0x00 (Get key)
    int 0x16        ; Call keyboard interrupt (to remove the key)
    jmp flush_esc_key ; Loop again

wait_esc_response:  ; Loop: Wait for 'P', 'S', or 'N'
    mov ah, 0x00    ; AH=0x00 (Get key)
    int 0x16        ; Call keyboard interrupt (waits for a key)
    
    cmp al, 'p'     ; Compare AL with 'p' (Continue)
    je resume_game
    cmp al, 'P'
    je resume_game
    cmp al, 's'     ; Compare AL with 's' (Exit Game)
    je exit_game_confirmed
    cmp al, 'S'
    je exit_game_confirmed
    cmp al, 'n'     ; Compare AL with 'n' (New Game / Main Menu)
    je exit_to_main_menu
    cmp al, 'N'
    je exit_to_main_menu
    
    jmp wait_esc_response ; If none of those, wait again

exit_game_confirmed: ; Label: User pressed 'S' to exit
    xor ax, ax      ; Zero out AX
    mov es, ax      ; Set ES to 0 (to access IVT)
    
    ; Restore keyboard ISR
    mov ax, [old_keyboard_isr]
    mov [es:9*4], ax
    mov ax, [old_keyboard_isr+2]
    mov [es:9*4+2], ax
    
    ; Restore timer ISR
    mov ax, [old_timer_isr]
    mov [es:8*4], ax
    mov ax, [old_timer_isr+2]
    mov [es:8*4+2], ax
    
    mov ax, 0x0003  ; Set 80x25 text mode
    int 0x10        ; Call BIOS video interrupt
    mov ax, 0x4c00  ; AH=0x4C (Terminate program)
    int 0x21        ; Call DOS interrupt

exit_to_main_menu:  ; Label: User pressed 'N'
    call reset_game ; Reset all game variables
    jmp main_menu_start ; Jump back to the main menu

resume_game:        ; Label: User pressed 'P'
    mov byte [esc_pressed], 0 ; Clear the ESC flag
    mov byte [game_paused], 0 ; Clear the pause flag
    jmp no_key      ; Jump back to the main game loop

move_left:          ; Label: User pressed Left Arrow
    cmp byte [player_lane], 0 ; Compare lane with 0 (Leftmost)
    je no_key       ; Jump if Equal (can't move left)
    dec byte [player_lane] ; Decrement lane (move left)
    jmp no_key      ; Jump to update screen

move_right:         ; Label: User pressed Right Arrow
    cmp byte [player_lane], 2 ; Compare lane with 2 (Rightmost)
    je no_key       ; Jump if Equal (can't move right)
    inc byte [player_lane] ; Increment lane (move right)
    jmp no_key      ; Jump to update screen

no_key:             ; Label: Main logic update part of the loop
    cmp byte [game_paused], 1 ; Check if game is paused
    je game_loop    ; Jump if Equal (if paused, skip all logic and just re-loop)
    
    cmp byte [game_over], 1 ; Check if game over flag is set
    je game_over_state ; Jump if Equal to the game over screen
    
    ; --- If game is running ---
    call spawn_car  ; Try to spawn a new car
    call spawn_coin ; Try to spawn a new coin
    call update_objects ; Move all active objects
    call check_collisions ; Check for player collision with cars
    call check_coins ; Check for player collision with coins
    
    ; Increment score over time
    mov ax, [frame_counter] ; Load frame counter
    inc ax          ; Increment it
    mov [frame_counter], ax ; Save it
    and ax, 0x001F  ; AND with 31 (00011111b)
    cmp ax, 0       ; Compare result with 0
    jne no_score_inc ; Jump if Not Equal (only increment score every 32 frames)
    inc word [score] ; Increment the score

no_score_inc:       ; Label: Skip score increment
    ; --- Draw the new frame ---
    call clrbuffer  ; Clear the off-screen buffer
    call draw_landscape ; Draw the scrolling landscape
    call draw_road  ; Draw the scrolling road
    call draw_all_cars ; Draw all active enemy cars
    call draw_all_coins ; Draw all active coins
    call draw_player_car ; Draw the player's car
    call draw_score ; Draw the score
    call flip_buffer ; Copy the buffer to the screen
    
    mov cx, 0x0001  ; Set up a small delay
    call delay      ; Call the delay
    jmp game_loop   ; Jump back to the start of the game loop

game_over_state:    ; Label: Called when game_over flag is 1
    ; Draw the final frame
    call clrbuffer  ; Clear buffer
    call draw_landscape ; Draw landscape
    call draw_road  ; Draw road
    call draw_all_cars ; Draw cars
    call draw_all_coins ; Draw coins
    call draw_player_car ; Draw player
    call draw_score ; Draw score
    call show_game_over_popup ; Draw the "Game Over" box
    call flip_buffer ; Copy to screen
    
    ; Wait for input
flush_key_loop_go:  ; Loop: Clear keyboard buffer
    mov ah, 0x01    ; AH=0x01 (Check status)
    int 0x16
    jz wait_key_press_go ; Jump if Zero (buffer empty)
    
    mov ah, 0x00    ; AH=0x00 (Get key)
    int 0x16        ; (to remove it)
    jmp flush_key_loop_go ; Loop

wait_key_press_go:  ; Loop: Wait for 'P' or 'S'
    mov ah, 0x01    ; AH=0x01 (Check status)
    int 0x16
    jz wait_key_press_go ; Jump if Zero (no key)
    
    mov ah, 0x00    ; AH=0x00 (Get key)
    int 0x16
    
    cmp al, 'p'     ; Compare with 'p' (Play Again)
    je restart_game_go
    cmp al, 'P'
    je restart_game_go
    cmp al, 'S'     ; Compare with 'S' (Main Menu)
    je exit_to_menu_go
    cmp al, 's'
    je exit_to_menu_go
    
    jmp wait_key_press_go ; If not 'p' or 's', wait again

restart_game_go:    ; Label: User pressed 'P'
    call reset_game ; Reset all game variables
    call clrscr     ; Clear the physical screen
    jmp game_loop   ; Jump back to the main game loop

exit_to_menu_go:    ; Label: User pressed 'S'
    call reset_game ; Reset all game variables
    jmp main_menu_start ; Jump back to the main menu