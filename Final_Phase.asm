[org 0x0100]

jmp start

;=== GAME VARIABLES ===
road_offset: dw 0
tree_offset: dw 0
score: dw 0
frame_counter: dw 0
game_over: db 0
random_seed: dw 0x1234
player_lane: db 1
old_keyboard_isr: dd 0
old_timer_isr: dd 0
esc_pressed: db 0
game_paused: db 0

car1: db 0, 0, 0
car2: db 0, 0, 0
car3: db 0, 0, 0
car4: db 0, 0, 0

coin1: db 0, 0, 0
coin2: db 0, 0, 0
coin3: db 0, 0, 0

buffer: times 4000 dw 0

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

clrscr:
    push es
    push ax
    push di
    push cx
    
    mov ax, 0xb800
    mov es, ax
    mov di, 0
    mov ax, 0x0720
    mov cx, 2000
    cld
    rep stosw
    
    pop cx
    pop di
    pop ax
    pop es
    ret

clrbuffer:
    push es
    push ax
    push di
    push cx
    
    push ds
    pop es
    mov di, buffer
    mov ax, 0x0020
    mov cx, 2000
    cld
    rep stosw
    
    pop cx
    pop di
    pop ax
    pop es
    ret

printchar_buf:
    push bx
    push di
    push ax
    
    cmp dh, 25
    jge printchar_buf_skip
    cmp dl, 80
    jge printchar_buf_skip
    
    push ax
    mov al, dh
    mov bl, 80
    mul bl
    mov bl, dl
    xor bh, bh
    add ax, bx
    shl ax, 1
    mov di, ax
    pop ax
    
    mov bx, buffer
    add di, bx
    mov [di], ax

printchar_buf_skip:
    pop ax
    pop di
    pop bx
    ret

print_string_buf:
    push ax
    push si
    
print_string_buf_loop:
    lodsb
    cmp al, 0
    je print_string_buf_done
    call printchar_buf
    inc dl
    jmp print_string_buf_loop
    
print_string_buf_done:
    pop si
    pop ax
    ret

flip_buffer:
    push es
    push ds
    push si
    push di
    push cx
    push dx
    
    mov dx, 0x3DA
flip_buffer_wait1:
    in al, dx
    test al, 0x08
    jnz flip_buffer_wait1
flip_buffer_wait2:
    in al, dx
    test al, 0x08
    jz flip_buffer_wait2
    
    mov ax, 0xb800
    mov es, ax
    push ds
    pop ds
    mov si, buffer
    xor di, di
    mov cx, 2000
    cld
    rep movsw
    
    pop dx
    pop cx
    pop di
    pop si
    pop ds
    pop es
    ret

get_random:
    push bx
    push dx
    
    mov ax, [random_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [random_seed], ax
    
    pop dx
    pop bx
    ret

delay:
    push cx
    push ax
    
    mov cx, 0x0001
delay_outer_d:
    push cx
    mov cx, 0xFFFF
delay_inner_d:
    nop
    loop delay_inner_d
    pop cx
    loop delay_outer_d
    
    pop ax
    pop cx
    ret

show_main_menu:
    mov ax, 0x0003
    int 0x10
    
    mov ah, 0x01
    mov ch, 0x32
    mov cl, 0x00
    int 0x10
    
    call clrbuffer
    
    ; Draw team info box in top right corner
    mov dh, 0
    mov dl, 52
    mov bl, 32
    mov bh, 8
    mov ah, 0x0B
    call draw_box_buf
    
    ; Draw team title centered
    mov dh, 1
    mov dl, 55
    mov ah, 0x0E
    mov si, team_title
    call print_string_buf
    
    ; Draw team member 1 info
    mov dh, 2
    mov dl, 55
    mov ah, 0x0B
    mov si, team1_name
    call print_string_buf
    
    mov dh, 3
    mov dl, 55
    mov ah, 0x0B
    mov si, team1_roll
    call print_string_buf
    
    ; Draw team member 2 info
    mov dh, 4
    mov dl, 55
    mov ah, 0x0B
    mov si, team2_name
    call print_string_buf
    
    mov dh, 5
    mov dl, 55
    mov ah, 0x0B
    mov si, team2_roll
    call print_string_buf
    
    ; Draw semester info centered
    mov dh, 6
    mov dl, 55
    mov ah, 0x0E
    mov si, semester_info
    call print_string_buf
    
    ; Draw title ASCII art - centered
    mov dh, 8
    mov dl, 16
    mov ah, 0x0E
    mov si, title_line1
    call print_string_buf
    
    mov dh, 9
    mov dl, 16
    mov ah, 0x0A
    mov si, title_line2
    call print_string_buf
    
    mov dh, 10
    mov dl, 16
    mov ah, 0x0B
    mov si, title_line3
    call print_string_buf
    
    mov dh, 11
    mov dl, 16
    mov ah, 0x09
    mov si, title_line4
    call print_string_buf
    
    mov dh, 12
    mov dl, 16
    mov ah, 0x0D
    mov si, title_line5
    call print_string_buf
    
    mov dh, 13
    mov dl, 16
    mov ah, 0x0C
    mov si, title_line6
    call print_string_buf
    
    mov dh, 14
    mov dl, 16
    mov ah, 0x0E
    mov si, title_line7
    call print_string_buf
    
    mov dh, 15
    mov dl, 16
    mov ah, 0x0A
    mov si, title_line8
    call print_string_buf
    
    mov dh, 16
    mov dl, 16
    mov ah, 0x0B
    mov si, title_line9
    call print_string_buf
    
    mov dh, 17
    mov dl, 16
    mov ah, 0x09
    mov si, title_line10
    call print_string_buf
    
    mov dh, 18
    mov dl, 16
    mov ah, 0x0D
    mov si, title_line11
    call print_string_buf
    
    mov dh, 19
    mov dl, 16
    mov ah, 0x0C
    mov si, title_line12
    call print_string_buf
    
    ; Draw "Press P to Play" - centered
    mov dh, 21
    mov dl, 31
    mov ah, 0x0F
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
    mov ah, 0x0A
    mov al, 'P'
    call printchar_buf
    inc dl
    mov ah, 0x0F
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
    mov dh, 23
    mov dl, 30
    mov ah, 0x0F
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
    mov ah, 0x0C
    mov al, 'E'
    call printchar_buf
    inc dl
    mov al, 'S'
    call printchar_buf
    inc dl
    mov al, 'C'
    call printchar_buf
    inc dl
    mov ah, 0x0F
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
    
    call flip_buffer

menu_wait_for_key:
    cmp byte [esc_pressed], 1
    je menu_handle_esc
    
    mov ah, 0x01
    int 0x16
    jz menu_wait_for_key
    
    mov ah, 0x00
    int 0x16
    
    cmp al, 'p'
    je start_game
    cmp al, 'P'
    je start_game
    
    jmp menu_wait_for_key

menu_handle_esc:
    ; Exit directly from main menu - no confirmation
    xor ax, ax
    mov es, ax
    
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
    
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4c00
    int 0x21

start_game:
    ret

draw_hline:
    push cx
    push dx
    
    mov cl, bl
    xor ch, ch
    
draw_hline_loop:
    call printchar_buf
    inc dl
    loop draw_hline_loop
    
    pop dx
    pop cx
    ret

draw_flower:
    push ax
    push dx
    mov al, '*'
    mov ah, 0x2E
    call printchar_buf
    inc dh
    mov al, '|'
    mov ah, 0x2A
    call printchar_buf
    pop dx
    pop ax
    ret

draw_bush_light:
    push ax
    push dx
    mov al, 0xB0
    mov ah, 0x2A
    call printchar_buf
    inc dl
    mov al, 0xB1
    mov ah, 0x2A
    call printchar_buf
    pop dx
    pop ax
    ret

draw_Bush:
    push ax
    push dx
    mov al, 219
    mov ah, 0x2a
    call printchar_buf
    inc dl
    mov al, 219
    mov ah, 0x2a
    call printchar_buf
    pop dx
    pop ax
    ret

draw_flowerR:
    push ax
    push dx
    mov al, '*'
    mov ah, 0x2c
    call printchar_buf
    inc dh
    mov al, '|'
    mov ah, 0x2A
    call printchar_buf
    pop dx
    pop ax
    ret

draw_flowerM:
    push ax
    push dx
    mov al, '*'
    mov ah, 0x25
    call printchar_buf
    inc dh
    mov al, '|'
    mov ah, 0x2A
    call printchar_buf
    pop dx
    pop ax
    ret

draw_big_tree:
    push ax
    push bx
    push cx
    push dx

    mov al, 219
    mov ah, 0x2A
    call printchar_buf

    inc dh
    dec dl
    mov al, 219
    mov ah, 0x2A
    call printchar_buf
    inc dl
    call printchar_buf
    inc dl
    call printchar_buf
    dec dl

    inc dh
    sub dl, 2
    mov cx, 5
draw_row3:
    mov al, 219
    mov ah, 0x2A
    call printchar_buf
    inc dl
    loop draw_row3
    sub dl, 3
    inc dh
    sub dl, 2
    mov cx, 5

draw_row4:
    mov al, 219
    mov ah, 0x2A
    call printchar_buf
    inc dl
    loop draw_row4
    sub dl, 3

    mov al, 219
    mov ah, 0x26
    inc dh
    call printchar_buf
    inc dh
    call printchar_buf
    inc dh
    call printchar_buf

    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_landscape:
    push ax
    push bx
    push cx
    push dx

    mov dh, 0
left_fill:
    mov dl, 0
    mov bl, 25
    mov al, 177
    mov ah, 0x22
    call draw_hline
    inc dh
    cmp dh, 25
    jl left_fill

    mov dh, 0
right_fill:
    mov dl, 55
    mov bl, 25
    mov al, 177
    mov ah, 0x22
    call draw_hline
    inc dh
    cmp dh, 25
    jl right_fill

    mov dh, 0
left_decorations:
    push dx
    xor ah, ah
    mov al, dh
    add ax, [tree_offset]
    xor dx, dx
    mov bx, 25
    div bx
    mov bx, dx
    pop dx
    
    cmp bx, 1
    jne left_dec_check2
    push dx
    mov dl, 5
    call draw_big_tree
    pop dx
    jmp left_dec_next

left_dec_check2:
    cmp bx, 10
    jne left_dec_check3
    push dx
    mov dl, 12
    call draw_big_tree
    pop dx
    jmp left_dec_next

left_dec_check3:
    cmp bx, 5
    jne left_dec_check4
    push dx
    mov dl, 18
    call draw_big_tree
    pop dx
    jmp left_dec_next

left_dec_check4:
    cmp bx, 15
    jne left_dec_check5
    push dx
    mov dl, 16
    call draw_big_tree
    pop dx
    jmp left_dec_next

left_dec_check5:
    cmp bx, 18
    jne left_dec_check6
    push dx
    mov dl, 4
    call draw_big_tree
    pop dx
    jmp left_dec_next

left_dec_check6:
    cmp bx, 19
    jne left_dec_check7
    push dx
    mov dl, 8
    call draw_flowerR
    pop dx
    jmp left_dec_next

left_dec_check7:
    cmp bx, 11
    jne left_dec_check8
    push dx
    mov dl, 4
    call draw_flowerR
    pop dx
    jmp left_dec_next

left_dec_check8:
    cmp bx, 16
    jne left_dec_check9
    push dx
    mov dl, 4
    call draw_flower
    pop dx
    jmp left_dec_next

left_dec_check9:
    cmp bx, 22
    jne left_dec_check10
    push dx
    mov dl, 23
    call draw_flowerM
    pop dx
    jmp left_dec_next

left_dec_check10:
    cmp bx, 7
    jne left_dec_check11
    push dx
    mov dl, 7
    call draw_flowerR
    pop dx
    jmp left_dec_next

left_dec_check11:
    cmp bx, 4
    jne left_dec_check12
    push dx
    mov dl, 9
    call draw_flowerM
    pop dx
    jmp left_dec_next

left_dec_check12:
    cmp bx, 6
    jne left_dec_check13
    push dx
    mov dl, 10
    call draw_flower
    pop dx
    jmp left_dec_next

left_dec_check13:
    cmp bx, 23
    jne left_dec_check14
    push dx
    mov dl, 14
    call draw_Bush
    pop dx
    jmp left_dec_next

left_dec_check14:
    cmp bx, 2
    jne left_dec_check15
    push dx
    mov dl, 12
    call draw_Bush
    pop dx
    jmp left_dec_next

left_dec_check15:
    cmp bx, 5
    jne left_dec_check16
    push dx
    mov dl, 22
    call draw_bush_light
    pop dx
    jmp left_dec_next

left_dec_check16:
    cmp bx, 14
    jne left_dec_next
    push dx
    mov dl, 20
    call draw_bush_light
    pop dx

left_dec_next:
    inc dh
    cmp dh, 25
    jl left_decorations

    mov dh, 0
right_decorations:
    push dx
    xor ah, ah
    mov al, dh
    add ax, [tree_offset]
    xor dx, dx
    mov bx, 25
    div bx
    mov bx, dx
    pop dx
    
    cmp bx, 5
    jne right_dec_check2
    push dx
    mov dl, 60
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check2:
    cmp bx, 1
    jne right_dec_check3
    push dx
    mov dl, 70
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check3:
    cmp bx, 12
    jne right_dec_check4
    push dx
    mov dl, 70
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check4:
    cmp bx, 8
    jne right_dec_check5
    push dx
    mov dl, 76
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check5:
    cmp bx, 18
    jne right_dec_check6
    push dx
    mov dl, 76
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check6:
    cmp bx, 16
    jne right_dec_check7
    push dx
    mov dl, 60
    call draw_big_tree
    pop dx
    jmp right_dec_next

right_dec_check7:
    cmp bx, 17
    jne right_dec_check8
    push dx
    mov dl, 65
    call draw_flowerM
    pop dx
    jmp right_dec_next

right_dec_check8:
    cmp bx, 2
    jne right_dec_check9
    push dx
    mov dl, 76
    call draw_flowerM
    pop dx
    jmp right_dec_next

right_dec_check9:
    cmp bx, 12
    jne right_dec_check10
    push dx
    mov dl, 63
    call draw_flower
    pop dx
    jmp right_dec_next

right_dec_check10:
    cmp bx, 23
    jne right_dec_check11
    push dx
    mov dl, 79
    call draw_flowerR
    pop dx
    jmp right_dec_next

right_dec_check11:
    cmp bx, 20
    jne right_dec_check12
    push dx
    mov dl, 66
    call draw_flower
    pop dx
    jmp right_dec_next

right_dec_check12:
    cmp bx, 10
    jne right_dec_check13
    push dx
    mov dl, 67
    call draw_flowerR
    pop dx
    jmp right_dec_next

right_dec_check13:
    cmp bx, 2
    jne right_dec_check14
    push dx
    mov dl, 63
    call draw_flower
    pop dx
    jmp right_dec_next

right_dec_check14:
    cmp bx, 9
    jne right_dec_check15
    push dx
    mov dl, 70
    call draw_Bush
    pop dx
    jmp right_dec_next

right_dec_check15:
    cmp bx, 23
    jne right_dec_check16
    push dx
    mov dl, 70
    call draw_Bush
    pop dx
    jmp right_dec_next

right_dec_check16:
    cmp bx, 24
    jne right_dec_check17
    push dx
    mov dl, 62
    call draw_bush_light
    pop dx
    jmp right_dec_next

right_dec_check17:
    cmp bx, 5
    jne right_dec_next
    push dx
    mov dl, 74
    call draw_bush_light
    pop dx

right_dec_next:
    inc dh
    cmp dh, 25
    jl right_decorations

    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_road:
    push ax
    push bx
    push cx
    push dx

    mov dh, 0 

road_loop:
    mov dl, 25 
    mov bl, 30 
    mov al, 176 
    mov ah, 0x08 
    call draw_hline

    mov dl, 25
    mov al, 219
    mov ah, 0x0F
    call printchar_buf

    mov dl, 54
    call printchar_buf

    mov ax, [road_offset] 
    xor ah, ah 
    add al, dh 
    mov bl, 3
    div bl 
    cmp ah, 0
    jne skip_divider 

    mov dl, 35
    mov al, 186 
    mov ah, 0x0F
    call printchar_buf

    mov dl, 44
    mov al, 186
    mov ah, 0x0F
    call printchar_buf

skip_divider:
    inc dh
    cmp dh, 25
    jl road_loop

    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_player_car:
    push ax
    push bx
    push dx
    
    xor bx, bx
    mov bl, [player_lane]
    mov dl, 29
    cmp bl, 1
    jne player_not_center
    mov dl, 38
    jmp player_got_col
player_not_center:
    cmp bl, 2
    jne player_got_col
    mov dl, 47
player_got_col:

    mov dh, 20
    mov al, 219
    mov ah, 0x0E
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x00
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x00
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x0E
    call printchar_buf
    
    add dh, 1
    sub dl, 3
    mov al, 219
    mov ah, 0x0E
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x0B
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x0B
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x0E
    call printchar_buf
    
    add dh, 1
    sub dl, 3
    mov al, 220
    mov ah, 0x0E
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x00
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x00
    call printchar_buf
    
    add dl, 1
    mov al, 220
    mov ah, 0x0E
    call printchar_buf
    
    pop dx
    pop bx
    pop ax
    ret

draw_other_car:
    push ax
    push bx
    push dx
    
    xor ax, ax
    mov al, bl
    mov dl, 29
    cmp al, 1
    jne other_not_center
    mov dl, 38
    jmp other_got_col
other_not_center:
    cmp al, 2
    jne other_got_col
    mov dl, 47
other_got_col:

    mov al, 219
    mov ah, 0x00
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x0e
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x0e
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x00
    call printchar_buf
    
    add dh, 1 
    sub dl, 3
    mov al, 219
    mov ah, 0x0E
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x04
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x04
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x0E
    call printchar_buf
    
    add dh, 1
    sub dl, 3
    mov al, 220
    mov ah, 0x8E
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x03
    call printchar_buf
    
    add dl, 1
    mov al, 219
    mov ah, 0x03
    call printchar_buf
    
    add dl, 1
    mov al, 220
    mov ah, 0x8E
    call printchar_buf
    
    pop dx
    pop bx
    pop ax
    ret

draw_coin:
    push ax
    push dx
    
    xor ax, ax
    mov al, bl
    mov dl, 30
    cmp al, 1
    jne coin_not_center
    mov dl, 39
    jmp coin_got_col
coin_not_center:
    cmp al, 2
    jne coin_got_col
    mov dl, 48
coin_got_col:

    inc dl
    mov al, 254
    mov ah, 0x0E
    call printchar_buf
    
    pop dx
    pop ax
    ret

update_objects:
    push ax
    push cx
    push si
    
    mov si, car1
    mov cx, 4
car_loop:
    cmp byte [si+2], 0
    je car_next
    
    mov al, [si]
    inc al
    cmp al, 24
    jl car_ok
    mov byte [si+2], 0
    jmp car_next
car_ok:
    mov [si], al
car_next:
    add si, 3
    loop car_loop
    
    mov si, coin1
    mov cx, 3
coin_loop:
    cmp byte [si+2], 0
    je coin_next
    
    mov al, [si]
    inc al
    cmp al, 24
    jl coin_ok
    mov byte [si+2], 0
    jmp coin_next
coin_ok:
    mov [si], al
coin_next:
    add si, 3
    loop coin_loop
    
    pop si
    pop cx
    pop ax
    ret

spawn_car:
    push ax
    push bx
    push cx
    push dx
    push si
    
    call get_random
    and ax, 0x003F
    cmp ax, 3
    jg no_spawn_car
    
    mov si, car1
    mov cx, 4
find_car:
    cmp byte [si+2], 0
    je found_car
    add si, 3
    loop find_car
    jmp no_spawn_car

found_car:
    mov byte [si], 0
    call get_random
    xor dx, dx
    mov bx, 3
    div bx
    mov [si+1], dl
    mov byte [si+2], 1

no_spawn_car:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

spawn_coin:
    push ax
    push bx
    push cx
    push dx
    push si
    
    call get_random
    and ax, 0x00FF
    cmp ax, 3
    jg no_spawn_coin
    
    mov si, coin1
    mov cx, 3
find_coin:
    cmp byte [si+2], 0
    je found_coin
    add si, 3
    loop find_coin
    jmp no_spawn_coin

found_coin:
    mov byte [si], 0
    call get_random
    xor dx, dx
    mov bx, 3
    div bx
    mov [si+1], dl
    mov byte [si+2], 1

no_spawn_coin:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

check_collisions:
    push ax
    push bx
    push cx
    push si
    
    xor bx, bx
    mov bl, [player_lane]
    
    mov si, car1
    mov cx, 4
collision_loop:
    cmp byte [si+2], 0
    je collision_next
    
    xor ax, ax
    mov al, [si]
    cmp ax, 17
    jl collision_next
    cmp ax, 23
    jg collision_next
    
    xor ax, ax
    mov al, [si+1]
    cmp ax, bx
    jne collision_next
    
    mov byte [game_over], 1

collision_next:
    add si, 3
    loop collision_loop
    
    pop si
    pop cx
    pop bx
    pop ax
    ret

check_coins:
    push ax
    push bx
    push cx
    push si
    
    xor bx, bx
    mov bl, [player_lane]
    
    mov si, coin1
    mov cx, 3
coin_check_loop:
    cmp byte [si+2], 0
    je coin_check_next
    
    xor ax, ax
    mov al, [si]
    cmp ax, 19
    jl coin_check_next
    cmp ax, 23
    jg coin_check_next
    
    xor ax, ax
    mov al, [si+1]
    cmp ax, bx
    jne coin_check_next
    
    mov byte [si+2], 0
    mov ax, [score]
    add ax, 5
    mov [score], ax

coin_check_next:
    add si, 3
    loop coin_check_loop
    
    pop si
    pop cx
    pop bx
    pop ax
    ret

draw_all_cars:
    push cx
    push dx
    push si
    
    mov si, car1
    mov cx, 4
draw_cars_loop:
    cmp byte [si+2], 0
    je draw_cars_next
    
    mov dh, [si]
    mov bl, [si+1]
    call draw_other_car

draw_cars_next:
    add si, 3
    loop draw_cars_loop
    
    pop si
    pop dx
    pop cx
    ret

draw_all_coins:
    push cx
    push dx
    push si
    
    mov si, coin1
    mov cx, 3
draw_coins_loop:
    cmp byte [si+2], 0
    je draw_coins_next
    
    mov dh, [si]
    mov bl, [si+1]
    call draw_coin

draw_coins_next:
    add si, 3
    loop draw_coins_loop
    
    pop si
    pop dx
    pop cx
    ret

draw_score:
    push ax
    push bx
    push cx
    push dx
    
    mov dh, 0
    mov dl, 63
    mov ah, 0x0F
    
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
    
    mov ax, [score]
    mov bx, 10
    xor cx, cx

    cmp ax, 0
    jne convert_score

    push 0
    inc cx
    jmp print_setup

convert_score:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz convert_score

print_setup:
    mov dh, 0
    mov dl, 70

print_score:
    pop bx
    mov al, bl
    add al, '0'
    mov ah, 0x0F
    push cx
    push dx
    call printchar_buf
	inc dl
	mov al, ' '
    call printchar_buf
    pop dx
    pop cx
    inc dl
    loop print_score

    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_box_buf:
    push ax
    push bx
    push cx
    push dx
    push si
    
    mov si, dx
    
    mov al, 201
    call printchar_buf
    
    mov cl, bl
    dec cl
    dec cl
draw_top_buf:
    inc dl
    mov al, 205
    call printchar_buf
    dec cl
    jnz draw_top_buf
    
    inc dl
    mov al, 187
    call printchar_buf
    
    mov dx, si
    mov cl, bh
    dec cl
    dec cl
    inc dh
draw_sides_buf:
    push dx
    mov al, 186
    call printchar_buf
    add dl, bl
    dec dl
    call printchar_buf
    pop dx
    inc dh
    dec cl
    jnz draw_sides_buf
    
    mov dx, si
    add dh, bh
    dec dh
    mov al, 200
    call printchar_buf
    
    mov cl, bl
    dec cl
    dec cl
draw_bottom_buf:
    inc dl
    mov al, 205
    call printchar_buf
    dec cl
    jnz draw_bottom_buf
    
    inc dl
    mov al, 188
    call printchar_buf
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

show_game_over_popup:
    push ax
    push bx
    push cx
    push dx
    push si
    
    mov dh, 8
    mov dl, 20
    mov bl, 40
    mov bh, 10
    mov ah, 0x4F
    call draw_box_buf
    
    mov dh, 9
popup_fill_loop:
    mov dl, 21
    mov cx, 38
popup_fill_row:
    mov al, ' '
    mov ah, 0x4F
    call printchar_buf
    inc dl
    loop popup_fill_row
    inc dh
    cmp dh, 17
    jl popup_fill_loop
    
    mov dh, 10
    mov dl, 34
    mov ah, 0x4E
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
    
    mov dh, 12
    mov dl, 32
    mov ah, 0x4F
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
    
    inc dl
    mov si, dx
    
    mov ax, [score]
    mov bx, 10
    xor cx, cx
    
    cmp ax, 0
    jne convert_popup_score
    
    mov al, '0'
    mov ah, 0x4F
    mov dx, si
    call printchar_buf
    jmp after_popup_score

convert_popup_score:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz convert_popup_score

print_popup_score_setup:
    mov dx, si

print_popup_score:
    pop ax
    add al, '0'
    mov ah, 0x4F
    call printchar_buf
    inc dl
    loop print_popup_score

after_popup_score:
    
    mov dh, 14
    mov dl, 28
    mov ah, 0x4F
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
    mov ah, 0x4A
    mov al, 'P'
    call printchar_buf
    inc dl
    mov ah, 0x4F
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
    
    mov dh, 15
    mov dl, 26
    mov ah, 0x4F
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
    mov ah, 0x4C
    mov al, 'S'
    call printchar_buf
    inc dl
    mov ah, 0x4F
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
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

reset_game:
    push ax
    push cx
    push si
    
    mov word [score], 0
    mov word [frame_counter], 0
    mov byte [game_over], 0
    mov byte [player_lane], 1
    mov word [road_offset], 0
    mov word [tree_offset], 0
    mov byte [esc_pressed], 0
    mov byte [game_paused], 0
    
    mov si, car1
    mov cx, 4
clear_cars:
    mov byte [si], 0
    mov byte [si+1], 0
    mov byte [si+2], 0
    add si, 3
    loop clear_cars
    
    mov si, coin1
    mov cx, 3
clear_coins:
    mov byte [si], 0
    mov byte [si+1], 0
    mov byte [si+2], 0
    add si, 3
    loop clear_coins
    
    pop si
    pop cx
    pop ax
    ret

keyboard_isr:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    
    mov ax, cs
    mov ds, ax
    
    in al, 0x60
    
    cmp al, 0x01
    jne keyboard_isr_chain
    
    mov byte [cs:esc_pressed], 1
    
    mov al, 0x20
    out 0x20, al
    
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

keyboard_isr_chain:
    mov al, 0x20
    out 0x20, al
    
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    jmp far [cs:old_keyboard_isr]

timer_isr:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    
    mov ax, cs
    mov ds, ax
    
    ; Only scroll if game is active (not paused, not game over)
    cmp byte [game_paused], 1
    je timer_skip_scroll
    cmp byte [game_over], 1
    je timer_skip_scroll
    
    ; Update road offset for scrolling
    mov ax, [road_offset]
    dec ax
    cmp ax, 0
    jge timer_road_ok
    mov ax, 2
timer_road_ok:
    mov [road_offset], ax
    
    ; Update tree offset for scrolling
    mov ax, [tree_offset]
    dec ax
    cmp ax, 0
    jge timer_tree_ok
    mov ax, 24
timer_tree_ok:
    mov [tree_offset], ax

timer_skip_scroll:
    ; Send EOI to PIC
    mov al, 0x20
    out 0x20, al
    
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    
    ; Chain to old timer ISR
    jmp far [cs:old_timer_isr]

show_exit_confirmation:
    push ax
    push bx
    push cx
    push dx
    push si
    
    mov dh, 9
    mov dl, 15
    mov bl, 50
    mov bh, 10
    mov ah, 0x4F
    call draw_box_buf
    
    mov dh, 10
popup_exit_fill:
    mov dl, 16
    mov cx, 48
popup_exit_row:
    mov al, ' '
    mov ah, 0x4F
    call printchar_buf
    inc dl
    loop popup_exit_row
    inc dh
    cmp dh, 18
    jl popup_exit_fill
    
    mov dh, 11
    mov dl, 27
    mov ah, 0x4E
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
    
    mov dh, 12
    mov dl, 32
    mov ah, 0x4E
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
    
    mov dh, 14
    mov dl, 32
    mov ah, 0x4F
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
    
    inc dl
    mov si, dx
    
    mov ax, [score]
    mov bx, 10
    xor cx, cx
    
    cmp ax, 0
    jne convert_exit_score
    
    mov al, '0'
    mov ah, 0x4F
    mov dx, si
    call printchar_buf
    jmp after_exit_score

convert_exit_score:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz convert_exit_score

print_exit_score_setup:
    mov dx, si

print_exit_score:
    pop ax
    add al, '0'
    mov ah, 0x4F
    call printchar_buf
    inc dl
    loop print_exit_score

after_exit_score:
    
    mov dh, 16
    mov dl, 21
    mov ah, 0x4F
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
    mov ah, 0x4A
    mov al, 'P'
    call printchar_buf
    inc dl
    mov ah, 0x4F
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
    mov ah, 0x4C
    mov al, 'S'
    call printchar_buf
    inc dl
    mov ah, 0x4F
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
    
    mov dh, 17
    mov dl, 26
    mov ah, 0x4F
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
    mov ah, 0x4A
    mov al, 'N'
    call printchar_buf
    inc dl
    mov ah, 0x4F
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
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

start:
    mov ax, 0x0003
    int 0x10
    
    mov ah, 0x00
    int 0x1A
    mov [random_seed], dx
    
    xor ax, ax
    mov es, ax
    mov ax, [es:9*4]
    mov [old_keyboard_isr], ax
    mov ax, [es:9*4+2]
    mov [old_keyboard_isr+2], ax
    
    ; Hook keyboard ISR and timer ISR
    cli
    mov word [es:9*4], keyboard_isr
    mov [es:9*4+2], cs
    
    ; Hook timer ISR (interrupt 0x08)
    mov ax, [es:8*4]
    mov [old_timer_isr], ax
    mov ax, [es:8*4+2]
    mov [old_timer_isr+2], ax
    
    mov word [es:8*4], timer_isr
    mov [es:8*4+2], cs
    sti

main_menu_start:
    call show_main_menu
    call clrscr

game_loop:
    cmp byte [esc_pressed], 1
    je handle_esc_press
    
    mov ah, 0x01
    int 0x16
    jz no_key
    
    mov ah, 0x00
    int 0x16
    
    cmp ah, 0x4B
    je move_left
    cmp ah, 0x4D
    je move_right
    
    jmp no_key

handle_esc_press:
    mov byte [game_paused], 1
    
    call clrbuffer
    call draw_landscape
    call draw_road
    call draw_all_cars
    call draw_all_coins
    call draw_player_car
    call draw_score
    call show_exit_confirmation
    call flip_buffer

flush_esc_key:
    mov ah, 0x01
    int 0x16
    jz wait_esc_response
    
    mov ah, 0x00
    int 0x16
    jmp flush_esc_key

wait_esc_response:
    mov ah, 0x00
    int 0x16
    
    cmp al, 'p'
    je resume_game
    cmp al, 'P'
    je resume_game
    cmp al, 's'
    je exit_game_confirmed
    cmp al, 'S'
    je exit_game_confirmed
    cmp al, 'n'
    je exit_to_main_menu
    cmp al, 'N'
    je exit_to_main_menu
    
    jmp wait_esc_response

exit_game_confirmed:
    xor ax, ax
    mov es, ax
    
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
    
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4c00
    int 0x21

exit_to_main_menu:
    call reset_game
    jmp main_menu_start

resume_game:
    mov byte [esc_pressed], 0
    mov byte [game_paused], 0
    jmp no_key

move_left:
    cmp byte [player_lane], 0
    je no_key
    dec byte [player_lane]
    jmp no_key

move_right:
    cmp byte [player_lane], 2
    je no_key
    inc byte [player_lane]
    jmp no_key

no_key:
    cmp byte [game_paused], 1
    je game_loop
    
    cmp byte [game_over], 1
    je game_over_state
    
    call spawn_car
    call spawn_coin
    call update_objects
    call check_collisions
    call check_coins
    
    mov ax, [frame_counter]
    inc ax
    mov [frame_counter], ax
    and ax, 0x001F
    cmp ax, 0
    jne no_score_inc
    inc word [score]

no_score_inc:
    call clrbuffer
    call draw_landscape
    call draw_road
    call draw_all_cars
    call draw_all_coins
    call draw_player_car
    call draw_score
    call flip_buffer
    
    mov cx, 0x0001
    call delay
    jmp game_loop

game_over_state:
    call clrbuffer
    call draw_landscape
    call draw_road
    call draw_all_cars
    call draw_all_coins
    call draw_player_car
    call draw_score
    call show_game_over_popup
    call flip_buffer
    
flush_key_loop_go:
    mov ah, 0x01
    int 0x16
    jz wait_key_press_go
    
    mov ah, 0x00
    int 0x16
    jmp flush_key_loop_go

wait_key_press_go:
    mov ah, 0x01
    int 0x16
    jz wait_key_press_go
    
    mov ah, 0x00
    int 0x16
    
    cmp al, 'p'
    je restart_game_go
    cmp al, 'P'
    je restart_game_go
    cmp al, 'S'
    je exit_to_menu_go
    cmp al, 's'
    je exit_to_menu_go
    
    jmp wait_key_press_go

restart_game_go:
    call reset_game
    call clrscr
    jmp game_loop

exit_to_menu_go:
    call reset_game
    jmp main_menu_start