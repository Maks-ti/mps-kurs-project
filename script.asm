

; переход в состояние STATE_ERROR происходит тогда, когда входной символ не соответсвует ни одному переходу в какое-либо состояние обработки
; переход в состояние STATE_START происходит при получении символа 'CLEAR' при данном символе всё подчищается и происходит переход в стартовое состояние
; СОСТОЯНИЯ КОНЕЧНОГО АВТОМАТА РАБОТЫ МПС
STATE_ERROR                 equ 00h ; ->
STATE_START                 equ 01h ; -> STATE_NEGATIVE_FIRST_ARG, STATE_FIRST_ARG
STATE_NEGATIVE_FIRST_ARG        equ 02h ; -> STATE_FIRST_ARG
STATE_FIRST_ARG             equ 03h ; -> STATE_FIRST_ARG, STATE_MUL_DIV_SIGN, STATE_SUM_SUB_SIGN
STATE_MUL_DIV_SIGN          equ 04h ; -> STATE_NEGATIVE_SECOND_ARG, STATE_SECOND_ARG
STATE_SUM_SUB_SIGN          equ 05h ; -> STATE_SECOND_ARG
STATE_NEGATIVE_SECOND_ARG       equ 06h ; -> STATE_SECOND_ARG
STATE_SECOND_ARG            equ 07h ; -> STATE_SECOND_ARG, STATE_COMPUTE_RESULT
STATE_COMPUTE_RESULT            equ 08h ; -> STATE_FIRST_RESULT, STATE_SUM_SUB_SIGN, STATE_MUL_DIV_SIGN, SATE_OVERFLOW
STATE_OVERFLOW              equ 09h ; ->

; сопоставление названий кнопок с их цифровым обозначением
BUTTON_1        equ 01h
BUTTON_2        equ 02h
BUTTON_3        equ 03h
BUTTON_4        equ 04h
BUTTON_5        equ 05h
BUTTON_6        equ 06h
BUTTON_7        equ 07h
BUTTON_8        equ 08h
BUTTON_9        equ 09h
BUTTON_0        equ 0ah
BUTTON_CLEAR        equ 0bh
BUTTON_COMPUTE      equ 0ch
BUTTON_PLUS         equ 0dh
BUTTON_MINUS        equ 0eh
BUTTON_DIV      equ 0fh
BUTTON_MUL      equ 10h

OPERATION_SIGN_MUL  equ 01h
OPERATION_SIGN_DIV  equ 02h
OPERATION_SIGN_SUB  equ 03h
OPERATION_SIGN_SUM  equ 04h

; VARIABLES (определение переменных)

bte equ 44h     ; Выдаваемый на ЖКИ байт
; Переменные функции get_button
row_n equ 41h
col_n equ 42h
N equ 40h ;номер нажатой клавиши
map_start equ 30h ;начало области хранения КС клавиатуры

; биты знаков аргументов (если true -> имеем отрицательный знак операнда)
first_arg_negative  equ 00h ; 20h.0
second_arg_negative     equ 01h ; 20h.1
result_sign     equ 02h ; 20h.2

; текущее состояние 
state   equ 50h ; состояние конечного автомата
; аргументы и элементы аргументов
arg1    equ 51h ; аргумент первый
arg2    equ 52h ; аргумент второй
arg1_el equ 53h ; очередной элемент аргумента 1 (однозначное десятичное десятичное число)
arg2_el equ 54h ; очередной элемент аргумента 2

operation_sign equ 55h ; сохраняем значение знака операции

; Reset Vector
org 0h ; processor reset vector
    ajmp start ; go to beginning of program
; Interrupt Vector
org 0003h         ; processor interrupt vector
    ajmp int_0    ; go to int0 interrupt service routine

; MAIN PROGRAM
org 100h
    ; RS = P3.5
    ; RW = P3.7
    ; E = P3.4
    ; data = P2
    ; keyboard - P0, P1
start:
    ; выполняем необходимые инициализации
    mov state, #STATE_START

    lcall indic_init

    setb EA  ; разрешаем все прерывания
    setb EX0 ; разрешение прерывания от int0

    main_loop:
    finish: sjmp main_loop ; loop forever

int_0: ; обработчик прерывания INT0
    ; запрещаем все прерывания 
    clr EA
    clr EX0
    ; читаем клавишу с калавиатуры
    lcall get_button ; номер кнопки запишется в -> N
    ; Запускаем обработку текущего состояния
    lcall CHECK_STATE_PROC
    ; разрешаем все прерывания
    setb EA
    setb EX0
    ; выходим из обработчика прерывания
    reti


; БЛОК С ПРОЦЕДУРАМИ
; --- --- --- --- --- --- --- --- --- 
; процедура получения номера нажатой на клавиатуре кнопки
; *** Опрос Клавиатуры - START *************************************
get_button:
        ;формирование КС
        ;установка "0" в начальные позиции
        mov a, #07Fh ;подготовка "бегущего нуля " (01111111)
        mov r0, #map_start ;адрес начала карты состояние
   opros:
        mov P0, a ;"бегущий нуль" в порт 0
        ; при установке бегущего нуля все значения необходимые для ввода уже были установлены

        mov b, P1 ;чтение
        anl b, #0Fh ;выделение значащих разрядов (у нас 4
        ;младших разрядов, поэтому умножаем на
        ;00001111)
        mov @r0, b ;записываем строку карты

        setb c ;подготовка нового опроса сдвиг "0"в
        rrc a ;следующую позицию
        inc r0 ;переходим к следующей ячейке КС
        cjne a, #11110111b, opros  ;пока ноль не сдвинется в 3-ый разрряд порта P0

        ;дешифрация карты
        mov r0, #map_start
    dc:
        mov a, @r0 ;читаем очередную стоку карты
        cjne a, #0Fh, dck ;если в значащих разрядах есть ноль (строка карты не равна 00001111)
        ;(нажата клавиша), переходим к dck
        inc r0 ;если не нажата - просмотр карты далее
        cjne r0, #(map_start+4), dc ;пока не закончились строки

        mov row_n, #4 ;если клавиша не нажата, устанавливаем
        mov col_n, #4 ;несуществующие значения
        sjmp end1 ;и переходим в конец

    dck:    ; клавиша нажата
        mov a, r0 ;в R0 – адрес ячейки
        clr c
        subb a, #map_start  ;вычитаем нач. адр. КС, чтобы узнать
        mov row_n, a ;номер строки
        mov a, @r0 ;берем содержимое ячейки КС для
        mov col_n, #0 ;определения № столбца (сначала № = 0)
    dloop1:
        rrc a ;последовательно сдвигаем вправо, т.к.
        ;значащие разряды - младшие
        jnc end1 ;пока не ноль вытиснится в перенос
        inc col_n
        mov r1, col_n
        cjne r1, #4, dloop1
        ;пока не сдвинем 4 раза

    end1:
        lcall get_num ;вызов подпрограммы опред. номера
        ret ;возврат из процедуры

    get_num:
        push a ;спасаем аккумулятор
        mov a, row_n
        cjne a, #4, gn_end
        mov N, #0 ;если row_n = 4, то ничего не нажато
        pop a
        ret
    gn_end:
        mov b, #4h
        mul ab ;умножаем row_n на 4 (т.к. 4 столбцов)
        add a, col_n
        inc a
        mov N, a
        pop a
        ret
; *** Опрос Клавиатуры - END ***************************************

; --- ПРОЦЕДУРА ВЫЗОВА ОБРАБОТЧИКА СОСТОЯНИЯ ---
; (на деле просто реализация конструкции switch/case для маршрутизации между обработчиками состояний)
CHECK_STATE_PROC:
    MOV A, state

    ; Проверка STATE_ERROR
    CJNE A, #STATE_ERROR, NOT_STATE_ERROR
    LJMP STATE_ERROR_HANDLER

    NOT_STATE_ERROR:

    ; Проверка STATE_START
    CJNE A, #STATE_START, NOT_STATE_START
    LJMP STATE_START_HANDLER

    NOT_STATE_START:

    ; Проверка STATE_NEGATIVE_FIRST_ARG
    CJNE A, #STATE_NEGATIVE_FIRST_ARG, NOT_STATE_NEGATIVE_FIRST_ARG
    LJMP STATE_NEGATIVE_FIRST_ARG_HANDLER

    NOT_STATE_NEGATIVE_FIRST_ARG:

    ; Проверка STATE_FIRST_ARG
    CJNE A, #STATE_FIRST_ARG, NOT_STATE_FIRST_ARG
    LJMP STATE_FIRST_ARG_HANDLER

    NOT_STATE_FIRST_ARG:

    ; Проверка STATE_MUL_DIV_SIGN
    CJNE A, #STATE_MUL_DIV_SIGN, NOT_STATE_MUL_DIV_SIGN
    LJMP STATE_MUL_DIV_SIGN_HANDLER

    NOT_STATE_MUL_DIV_SIGN:

    ; Проверка STATE_SUM_SUB_SIGN
    CJNE A, #STATE_SUM_SUB_SIGN, NOT_STATE_SUM_SUB_SIGN
    LJMP STATE_SUM_SUB_SIGN_HANDLER

    NOT_STATE_SUM_SUB_SIGN:

    ; Проверка STATE_NEGATIVE_SECOND_ARG
    CJNE A, #STATE_NEGATIVE_SECOND_ARG, NOT_STATE_NEGATIVE_SECOND_ARG
    LJMP STATE_NEGATIVE_SECOND_ARG_HANDLER

    NOT_STATE_NEGATIVE_SECOND_ARG:

    ; Проверка STATE_SECOND_ARG
    CJNE A, #STATE_SECOND_ARG, NOT_STATE_SECOND_ARG
    LJMP STATE_SECOND_ARG_HANDLER

    NOT_STATE_SECOND_ARG:

    ; Проверка STATE_COMPUTE_RESULT
    CJNE A, #STATE_COMPUTE_RESULT, NOT_STATE_COMPUTE_RESULT
    LJMP STATE_COMPUTE_RESULT_HANDLER

    NOT_STATE_COMPUTE_RESULT:

    ; Проверка STATE_OVERFLOW
    CJNE A, #STATE_OVERFLOW, NOT_STATE_OVERFLOW
    LJMP STATE_OVERFLOW_HANDLER

    NOT_STATE_OVERFLOW:
    ; Переход по умолчанию, если ни одно состояние не совпало
    LJMP DEFAULT_HANDLER

    DEFAULT_HANDLER:
    ; Обработка ошибок или другие действия при отсутствии соответствия
    ret


; --- ПРОЦЕДУРЫ ОБРАБОТКИ СОСТОЯНИЙ --- 

; --- --- --- STATE_ERROR_HANDLER --- --- --- START
STATE_ERROR_HANDLER:
    MOV A, N
    CJNE A, #BUTTON_CLEAR, STATE_ERROR_NOT_BUTTON_CLEAR
    mov state, #STATE_START
    lcall CLEAR_ALL
    ret

    STATE_ERROR_NOT_BUTTON_CLEAR: ; не нажата ни одна подходящая кнопка
    ret
; --- --- --- STATE_ERROR_HANDLER --- --- --- END


; --- --- --- STATE_START_HANDLER --- --- --- START
STATE_START_HANDLER:
    mov A, N
    CJNE A, #BUTTON_MINUS, STATE_START_NOT_BUTTON_MINUS
    SETB first_arg_negative ; утсанавливаем флаг отрицательности аргумента
    mov state, #STATE_NEGATIVE_FIRST_ARG ; переход в новое состояние
    mov bte, '-' ; формируем байт для вывода на жки
    lcall send_data ; отправляем данные для отрисовки на жки
    ret

    STATE_START_NOT_BUTTON_MINUS:
    CJNE A, #BUTTON_0, STATE_START_NOT_BUTTON_0
    mov arg1_el, #0h
    lcall FORM_ARG_1
    mov bte, #'0'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_START_NOT_BUTTON_0:
    CJNE A, #BUTTON_1, STATE_START_NOT_BUTTON_1
    mov arg1_el, #1h
    lcall FORM_ARG_1
    mov bte, #'1'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_START_NOT_BUTTON_1:
    CJNE A, #BUTTON_2, STATE_START_NOT_BUTTON_2
    mov arg1_el, #2h
    lcall FORM_ARG_1
    mov bte, #'2'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_START_NOT_BUTTON_2:
    CJNE A, #BUTTON_3, STATE_START_NOT_BUTTON_3
    mov arg1_el, #3h
    lcall FORM_ARG_1
    mov bte, #'3'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_START_NOT_BUTTON_3:
    CJNE A, #BUTTON_4, STATE_START_NOT_BUTTON_4
    mov arg1_el, #4h
    lcall FORM_ARG_1
    mov bte, #'4'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_START_NOT_BUTTON_4:
    CJNE A, #BUTTON_5, STATE_START_NOT_BUTTON_5
    mov arg1_el, #5h
    lcall FORM_ARG_1
    mov bte, #'5'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_START_NOT_BUTTON_5:
    CJNE A, #BUTTON_6, STATE_START_NOT_BUTTON_6
    mov arg1_el, #6h
    lcall FORM_ARG_1
    mov bte, #'6'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_START_NOT_BUTTON_6:
    CJNE A, #BUTTON_7, STATE_START_NOT_BUTTON_7
    mov arg1_el, #7h
    lcall FORM_ARG_1
    mov bte, #'7'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_START_NOT_BUTTON_7:
    CJNE A, #BUTTON_8, STATE_START_NOT_BUTTON_8
    mov arg1_el, #8h
    lcall FORM_ARG_1
    mov bte, #'8'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_START_NOT_BUTTON_8:
    CJNE A, #BUTTON_9, STATE_START_NOT_BUTTON_9
    mov arg1_el, #9h
    lcall FORM_ARG_1
    mov bte, #'9'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_START_NOT_BUTTON_9:
    CJNE A, #BUTTON_CLEAR, STATE_START_NOT_BUTTON_CLEAR
    mov state, #STATE_START
    lcall CLEAR_ALL
    ret

    STATE_START_NOT_BUTTON_CLEAR: ; не нажата ни одна подходящая кнопка
    mov state, #STATE_ERROR
    lcall print_error_message
    ret
; --- --- --- STATE_START_HANDLER --- --- --- END


; --- --- --- STATE_NEGATIVE_FIRST_ARG_HANDLER --- --- --- START
STATE_NEGATIVE_FIRST_ARG_HANDLER:
    MOV A, N
    CJNE A, #BUTTON_0, STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_0
    mov arg1_el, #0h
    lcall FORM_ARG_1
    mov bte, #'0'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_0:
    CJNE A, #BUTTON_1, STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_1
    mov arg1_el, #1h
    lcall FORM_ARG_1
    mov bte, #'1'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_1:
    CJNE A, #BUTTON_2, STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_2
    mov arg1_el, #2h
    lcall FORM_ARG_1
    mov bte, #'2'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_2:
    CJNE A, #BUTTON_3, STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_3
    mov arg1_el, #3h
    lcall FORM_ARG_1
    mov bte, #'3'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_3:
    CJNE A, #BUTTON_4, STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_4
    mov arg1_el, #4h
    lcall FORM_ARG_1
    mov bte, #'4'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_4:
    CJNE A, #BUTTON_5, STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_5
    mov arg1_el, #5h
    lcall FORM_ARG_1
    mov bte, #'5'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_5:
    CJNE A, #BUTTON_6, STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_6
    mov arg1_el, #6h
    lcall FORM_ARG_1
    mov bte, #'6'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_6:
    CJNE A, #BUTTON_7, STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_7
    mov arg1_el, #7h
    lcall FORM_ARG_1
    mov bte, #'7'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_7:
    CJNE A, #BUTTON_8, STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_8
    mov arg1_el, #8h
    lcall FORM_ARG_1
    mov bte, #'8'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_8:
    CJNE A, #BUTTON_9, STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_9
    mov arg1_el, #9h
    lcall FORM_ARG_1
    mov bte, #'9'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_9:
    CJNE A, #BUTTON_CLEAR, STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_CLEAR
    mov state, #STATE_START
    lcall CLEAR_ALL
    ret

    STATE_NEGATIVE_FIRST_ARG_NOT_BUTTON_CLEAR: ; не нажата ни одна подходящая кнопка
    mov state, #STATE_ERROR
    lcall print_error_message
    ret
; --- --- --- STATE_NEGATIVE_FIRST_ARG_HANDLER --- --- --- END


; --- --- --- STATE_FIRST_ARG_HANDLER --- --- --- START
STATE_FIRST_ARG_HANDLER:
    MOV A, N
    CJNE A, #BUTTON_0, STATE_FIRST_ARG_NOT_BUTTON_0
    mov arg1_el, #0h
    lcall FORM_ARG_1
    mov bte, #'0'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_FIRST_ARG_NOT_BUTTON_0:
    CJNE A, #BUTTON_1, STATE_FIRST_ARG_NOT_BUTTON_1
    mov arg1_el, #1h
    lcall FORM_ARG_1
    mov bte, #'1'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_FIRST_ARG_NOT_BUTTON_1:
    CJNE A, #BUTTON_2, STATE_FIRST_ARG_NOT_BUTTON_2
    mov arg1_el, #2h
    lcall FORM_ARG_1
    mov bte, #'2'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_FIRST_ARG_NOT_BUTTON_2:
    CJNE A, #BUTTON_3, STATE_FIRST_ARG_NOT_BUTTON_3
    mov arg1_el, #3h
    lcall FORM_ARG_1
    mov bte, #'3'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_FIRST_ARG_NOT_BUTTON_3:
    CJNE A, #BUTTON_4, STATE_FIRST_ARG_NOT_BUTTON_4
    mov arg1_el, #4h
    lcall FORM_ARG_1
    mov bte, #'4'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_FIRST_ARG_NOT_BUTTON_4:
    CJNE A, #BUTTON_5, STATE_FIRST_ARG_NOT_BUTTON_5
    mov arg1_el, #5h
    lcall FORM_ARG_1
    mov bte, #'5'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_FIRST_ARG_NOT_BUTTON_5:
    CJNE A, #BUTTON_6, STATE_FIRST_ARG_NOT_BUTTON_6
    mov arg1_el, #6h
    lcall FORM_ARG_1
    mov bte, #'6'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_FIRST_ARG_NOT_BUTTON_6:
    CJNE A, #BUTTON_7, STATE_FIRST_ARG_NOT_BUTTON_7
    mov arg1_el, #7h
    lcall FORM_ARG_1
    mov bte, #'7'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_FIRST_ARG_NOT_BUTTON_7:
    CJNE A, #BUTTON_8, STATE_FIRST_ARG_NOT_BUTTON_8
    mov arg1_el, #8h
    lcall FORM_ARG_1
    mov bte, #'8'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_FIRST_ARG_NOT_BUTTON_8:
    CJNE A, #BUTTON_9, STATE_FIRST_ARG_NOT_BUTTON_9
    mov arg1_el, #9h
    lcall FORM_ARG_1
    mov bte, #'9'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_FIRST_ARG_NOT_BUTTON_9:
    CJNE A, #BUTTON_MUL, STATE_FIRST_ARG_NOT_BUTTON_MUL
    mov state, #STATE_MUL_DIV_SIGN
    mov bte, #'*'
    lcall send_data
    mov operation_sign, #OPERATION_SIGN_MUL
    ret

    STATE_FIRST_ARG_NOT_BUTTON_MUL:
    CJNE A, #BUTTON_DIV, STATE_FIRST_ARG_NOT_BUTTON_DIV
    mov state, #STATE_MUL_DIV_SIGN
    mov bte, #'/'
    lcall send_data
    mov operation_sign, #OPERATION_SIGN_DIV
    ret

    STATE_FIRST_ARG_NOT_BUTTON_DIV:
    CJNE A, #BUTTON_MINUS, STATE_FIRST_ARG_NOT_BUTTON_MINUS
    mov state, #STATE_SUM_SUB_SIGN
    mov bte, #'-'
    lcall send_data
    mov operation_sign, #OPERATION_SIGN_SUB
    ret

    STATE_FIRST_ARG_NOT_BUTTON_MINUS:
    CJNE A, #BUTTON_PLUS, STATE_FIRST_ARG_NOT_BUTTON_PLUS
    mov state, #STATE_SUM_SUB_SIGN
    mov bte, #'+'
    lcall send_data
    mov operation_sign, #OPERATION_SIGN_SUM
    ret

    STATE_FIRST_ARG_NOT_BUTTON_PLUS:
    CJNE A, #BUTTON_CLEAR, STATE_FIRST_ARG_NOT_BUTTON_CLEAR
    mov state, #STATE_START
    lcall CLEAR_ALL
    ret

    STATE_FIRST_ARG_NOT_BUTTON_CLEAR: ; не нажата ни одна подходящая кнопка
    mov state, #STATE_ERROR
    lcall print_error_message
    ret
; --- --- --- STATE_FIRST_ARG_HANDLER --- --- --- END


; --- --- --- STATE_MUL_DIV_SIGN_HANDLER --- --- --- START
STATE_MUL_DIV_SIGN_HANDLER:
    mov A, N
    CJNE A, #BUTTON_MINUS, STATE_MUL_DIV_SIGN_NOT_BUTTON_MINUS
    SETB second_arg_negative ; утсанавливаем флаг отрицательности аргумента
    mov state, #STATE_NEGATIVE_SECOND_ARG ; переход в новое состояние
    mov bte, #'-' ; формируем байт для вывода на жки
    lcall send_data ; отправляем данные для отрисовки на жки
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_MINUS:
    CJNE A, #BUTTON_0, STATE_MUL_DIV_SIGN_NOT_BUTTON_0
    mov arg2_el, #0h
    lcall FORM_ARG_2
    mov bte, #'0'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_0:
    CJNE A, #BUTTON_1, STATE_MUL_DIV_SIGN_NOT_BUTTON_1
    mov arg2_el, #1h
    lcall FORM_ARG_2
    mov bte, #'1'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_1:
    CJNE A, #BUTTON_2, STATE_MUL_DIV_SIGN_NOT_BUTTON_2
    mov arg2_el, #2h
    lcall FORM_ARG_2
    mov bte, #'2'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_2:
    CJNE A, #BUTTON_3, STATE_MUL_DIV_SIGN_NOT_BUTTON_3
    mov arg2_el, #3h
    lcall FORM_ARG_2
    mov bte, #'3'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_3:
    CJNE A, #BUTTON_4, STATE_MUL_DIV_SIGN_NOT_BUTTON_4
    mov arg2_el, #4h
    lcall FORM_ARG_2
    mov bte, #'4'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_4:
    CJNE A, #BUTTON_5, STATE_MUL_DIV_SIGN_NOT_BUTTON_5
    mov arg2_el, #5h
    lcall FORM_ARG_2
    mov bte, #'5'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_5:
    CJNE A, #BUTTON_6, STATE_MUL_DIV_SIGN_NOT_BUTTON_6
    mov arg2_el, #6h
    lcall FORM_ARG_2
    mov bte, #'6'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_6:
    CJNE A, #BUTTON_7, STATE_MUL_DIV_SIGN_NOT_BUTTON_7
    mov arg2_el, #7h
    lcall FORM_ARG_2
    mov bte, #'7'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_7:
    CJNE A, #BUTTON_8, STATE_MUL_DIV_SIGN_NOT_BUTTON_8
    mov arg2_el, #8h
    lcall FORM_ARG_2
    mov bte, #'8'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_8:
    CJNE A, #BUTTON_9, STATE_MUL_DIV_SIGN_NOT_BUTTON_9
    mov arg2_el, #9h
    lcall FORM_ARG_2
    mov bte, #'9'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_9:
    CJNE A, #BUTTON_CLEAR, STATE_MUL_DIV_SIGN_NOT_BUTTON_CLEAR
    mov state, #STATE_START
    lcall CLEAR_ALL
    ret

    STATE_MUL_DIV_SIGN_NOT_BUTTON_CLEAR: ; не нажата ни одна подходящая кнопка
    mov state, #STATE_ERROR
    lcall print_error_message
    ret
; --- --- --- STATE_MUL_DIV_SIGN_HANDLER --- --- --- END


; --- --- --- STATE_SUM_SUB_SIGN_HANDLER --- --- --- START
STATE_SUM_SUB_SIGN_HANDLER:
    MOV A, N
    CJNE A, #BUTTON_0, STATE_SUM_SUB_SIGN_NOT_BUTTON_0
    mov arg2_el, #0h
    lcall FORM_ARG_2
    mov bte, #'0'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SUM_SUB_SIGN_NOT_BUTTON_0:
    CJNE A, #BUTTON_1, STATE_SUM_SUB_SIGN_NOT_BUTTON_1
    mov arg2_el, #1h
    lcall FORM_ARG_2
    mov bte, #'1'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SUM_SUB_SIGN_NOT_BUTTON_1:
    CJNE A, #BUTTON_2, STATE_SUM_SUB_SIGN_NOT_BUTTON_2
    mov arg2_el, #2h
    lcall FORM_ARG_2
    mov bte, #'2'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SUM_SUB_SIGN_NOT_BUTTON_2:
    CJNE A, #BUTTON_3, STATE_SUM_SUB_SIGN_NOT_BUTTON_3
    mov arg2_el, #3h
    lcall FORM_ARG_2
    mov bte, #'3'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SUM_SUB_SIGN_NOT_BUTTON_3:
    CJNE A, #BUTTON_4, STATE_SUM_SUB_SIGN_NOT_BUTTON_4
    mov arg2_el, #4h
    lcall FORM_ARG_2
    mov bte, #'4'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SUM_SUB_SIGN_NOT_BUTTON_4:
    CJNE A, #BUTTON_5, STATE_SUM_SUB_SIGN_NOT_BUTTON_5
    mov arg2_el, #5h
    lcall FORM_ARG_2
    mov bte, #'5'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SUM_SUB_SIGN_NOT_BUTTON_5:
    CJNE A, #BUTTON_6, STATE_SUM_SUB_SIGN_NOT_BUTTON_6
    mov arg2_el, #6h
    lcall FORM_ARG_2
    mov bte, #'6'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SUM_SUB_SIGN_NOT_BUTTON_6:
    CJNE A, #BUTTON_7, STATE_SUM_SUB_SIGN_NOT_BUTTON_7
    mov arg2_el, #7h
    lcall FORM_ARG_2
    mov bte, #'7'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SUM_SUB_SIGN_NOT_BUTTON_7:
    CJNE A, #BUTTON_8, STATE_SUM_SUB_SIGN_NOT_BUTTON_8
    mov arg2_el, #8h
    lcall FORM_ARG_2
    mov bte, #'8'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SUM_SUB_SIGN_NOT_BUTTON_8:
    CJNE A, #BUTTON_9, STATE_SUM_SUB_SIGN_NOT_BUTTON_9
    mov arg2_el, #9h
    lcall FORM_ARG_2
    mov bte, #'9'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SUM_SUB_SIGN_NOT_BUTTON_9:
    CJNE A, #BUTTON_CLEAR, STATE_SUM_SUB_SIGN_NOT_BUTTON_CLEAR
    mov state, #STATE_START
    lcall CLEAR_ALL
    ret

    STATE_SUM_SUB_SIGN_NOT_BUTTON_CLEAR: ; не нажата ни одна подходящая кнопка
    mov state, #STATE_ERROR
    lcall print_error_message
    ret
; --- --- --- STATE_SUM_SUB_SIGN_HANDLER --- --- --- END


; --- --- --- STATE_NEGATIVE_SECOND_ARG_HANDLER --- --- --- START
STATE_NEGATIVE_SECOND_ARG_HANDLER:
    MOV A, N
    CJNE A, #BUTTON_0, STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_0
    mov arg2_el, #0h
    lcall FORM_ARG_2
    mov bte, #'0'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_0:
    CJNE A, #BUTTON_1, STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_1
    mov arg2_el, #1h
    lcall FORM_ARG_2
    mov bte, #'1'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_1:
    CJNE A, #BUTTON_2, STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_2
    mov arg2_el, #2h
    lcall FORM_ARG_2
    mov bte, #'2'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_2:
    CJNE A, #BUTTON_3, STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_3
    mov arg2_el, #3h
    lcall FORM_ARG_2
    mov bte, #'3'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_3:
    CJNE A, #BUTTON_4, STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_4
    mov arg2_el, #4h
    lcall FORM_ARG_2
    mov bte, #'4'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_4:
    CJNE A, #BUTTON_5, STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_5
    mov arg2_el, #5h
    lcall FORM_ARG_2
    mov bte, #'5'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_5:
    CJNE A, #BUTTON_6, STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_6
    mov arg2_el, #6h
    lcall FORM_ARG_2
    mov bte, #'6'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_6:
    CJNE A, #BUTTON_7, STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_7
    mov arg2_el, #7h
    lcall FORM_ARG_2
    mov bte, #'7'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_7:
    CJNE A, #BUTTON_8, STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_8
    mov arg2_el, #8h
    lcall FORM_ARG_2
    mov bte, #'8'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_8:
    CJNE A, #BUTTON_9, STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_9
    mov arg2_el, #9h
    lcall FORM_ARG_2
    mov bte, #'9'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_9:
    CJNE A, #BUTTON_CLEAR, STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_CLEAR
    mov state, #STATE_START
    lcall CLEAR_ALL
    ret

    STATE_NEGATIVE_SECOND_ARG_NOT_BUTTON_CLEAR: ; не нажата ни одна подходящая кнопка
    mov state, #STATE_ERROR
    lcall print_error_message
    ret
; --- --- --- STATE_NEGATIVE_SECOND_ARG_HANDLER --- --- --- END


; --- --- --- STATE_SECOND_ARG_HANDLER --- --- --- START
STATE_SECOND_ARG_HANDLER:
    MOV A, N
    CJNE A, #BUTTON_0, STATE_SECOND_ARG_NOT_BUTTON_0
    mov arg2_el, #0h
    lcall FORM_ARG_2
    mov bte, #'0'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SECOND_ARG_NOT_BUTTON_0:
    CJNE A, #BUTTON_1, STATE_SECOND_ARG_NOT_BUTTON_1
    mov arg2_el, #1h
    lcall FORM_ARG_2
    mov bte, #'1'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SECOND_ARG_NOT_BUTTON_1:
    CJNE A, #BUTTON_2, STATE_SECOND_ARG_NOT_BUTTON_2
    mov arg2_el, #2h
    lcall FORM_ARG_2
    mov bte, #'2'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SECOND_ARG_NOT_BUTTON_2:
    CJNE A, #BUTTON_3, STATE_SECOND_ARG_NOT_BUTTON_3
    mov arg2_el, #3h
    lcall FORM_ARG_2
    mov bte, #'3'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SECOND_ARG_NOT_BUTTON_3:
    CJNE A, #BUTTON_4, STATE_SECOND_ARG_NOT_BUTTON_4
    mov arg2_el, #4h
    lcall FORM_ARG_2
    mov bte, #'4'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SECOND_ARG_NOT_BUTTON_4:
    CJNE A, #BUTTON_5, STATE_SECOND_ARG_NOT_BUTTON_5
    mov arg2_el, #5h
    lcall FORM_ARG_2
    mov bte, #'5'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SECOND_ARG_NOT_BUTTON_5:
    CJNE A, #BUTTON_6, STATE_SECOND_ARG_NOT_BUTTON_6
    mov arg2_el, #6h
    lcall FORM_ARG_2
    mov bte, #'6'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SECOND_ARG_NOT_BUTTON_6:
    CJNE A, #BUTTON_7, STATE_SECOND_ARG_NOT_BUTTON_7
    mov arg2_el, #7h
    lcall FORM_ARG_2
    mov bte, #'7'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SECOND_ARG_NOT_BUTTON_7:
    CJNE A, #BUTTON_8, STATE_SECOND_ARG_NOT_BUTTON_8
    mov arg2_el, #8h
    lcall FORM_ARG_2
    mov bte, #'8'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SECOND_ARG_NOT_BUTTON_8:
    CJNE A, #BUTTON_9, STATE_SECOND_ARG_NOT_BUTTON_9
    mov arg2_el, #9h
    lcall FORM_ARG_2
    mov bte, #'9'
    lcall send_data
    mov state, #STATE_SECOND_ARG
    ret

    STATE_SECOND_ARG_NOT_BUTTON_9:
    CJNE A, #BUTTON_COMPUTE, STATE_SECOND_ARG_NOT_BUTTON_COMPUTE
    mov bte, #'='
    lcall send_data
    mov state, #STATE_COMPUTE_RESULT
    lcall COMPUTE_RESULT ; вызываем процедуру вычисления резульатта (результат сохраняется в arg1)
    ; данный метод может изменить значение state -> STATE_OVERFLOW
    mov A, state
    CJNE A, #STATE_COMPUTE_RESULT, STATE_SECOND_ARG_COMPUTE_BUTTON_END
    lcall print_result ; вызываем процедуру отрисовки результата
    STATE_SECOND_ARG_COMPUTE_BUTTON_END:
    ret

    STATE_SECOND_ARG_NOT_BUTTON_COMPUTE:
    CJNE A, #BUTTON_CLEAR, STATE_SECOND_ARG_NOT_BUTTON_CLEAR
    mov state, #STATE_START
    lcall CLEAR_ALL
    ret

    STATE_SECOND_ARG_NOT_BUTTON_CLEAR: ; не нажата ни одна подходящая кнопка
    mov state, #STATE_ERROR
    lcall print_error_message
    ret
; --- --- --- STATE_SECOND_ARG_HANDLER --- --- --- END


; --- --- --- STATE_COMPUTE_RESULT_HANDLER --- --- --- START
STATE_COMPUTE_RESULT_HANDLER:
    ; очищаем второй аргумент
    MOV arg2, #00h
    CLR second_arg_negative
    MOV arg2_el, #00h
    ; далее как обычно - читаем кнопки
    MOV A, N
    CJNE A, #BUTTON_MUL, STATE_COMPUTE_RESULT_NOT_BUTTON_MUL
    lcall clear_display
    lcall print_result
    mov state, #STATE_MUL_DIV_SIGN
    mov bte, #'*'
    lcall send_data
    mov operation_sign, #OPERATION_SIGN_MUL
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_MUL:
    CJNE A, #BUTTON_DIV, STATE_COMPUTE_RESULT_NOT_BUTTON_DIV
    lcall clear_display
    lcall print_result
    mov state, #STATE_MUL_DIV_SIGN
    mov bte, #'/'
    lcall send_data
    mov operation_sign, #OPERATION_SIGN_DIV
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_DIV:
    CJNE A, #BUTTON_MINUS, STATE_COMPUTE_RESULT_NOT_BUTTON_MINUS
    lcall clear_display
    lcall print_result
    mov state, #STATE_SUM_SUB_SIGN
    mov bte, #'-'
    lcall send_data
    mov operation_sign, #OPERATION_SIGN_SUB
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_MINUS:
    CJNE A, #BUTTON_PLUS, STATE_COMPUTE_RESULT_NOT_BUTTON_PLUS
    lcall clear_display
    lcall print_result
    mov state, #STATE_SUM_SUB_SIGN
    mov bte, #'+'
    lcall send_data
    mov operation_sign, #OPERATION_SIGN_SUM
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_PLUS:
    ; если входная кнопка - не арифметическая операция - то очистим и первый аргумент
    MOV arg1, #00h
    CLR first_arg_negative
    MOV arg1_el, #00h
    lcall clear_display ; очищаем дисплей
    ; далее как обычно проверяем кнопки
    CJNE A, #BUTTON_0, STATE_COMPUTE_RESULT_NOT_BUTTON_0
    mov arg1_el, #0h
    lcall FORM_ARG_1
    mov bte, #'0'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_0:
    CJNE A, #BUTTON_1, STATE_COMPUTE_RESULT_NOT_BUTTON_1
    mov arg1_el, #1h
    lcall FORM_ARG_1
    mov bte, #'1'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_1:
    CJNE A, #BUTTON_2, STATE_COMPUTE_RESULT_NOT_BUTTON_2
    mov arg1_el, #2h
    lcall FORM_ARG_1
    mov bte, #'2'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_2:
    CJNE A, #BUTTON_3, STATE_COMPUTE_RESULT_NOT_BUTTON_3
    mov arg1_el, #3h
    lcall FORM_ARG_1
    mov bte, #'3'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_3:
    CJNE A, #BUTTON_4, STATE_COMPUTE_RESULT_NOT_BUTTON_4
    mov arg1_el, #4h
    lcall FORM_ARG_1
    mov bte, #'4'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_4:
    CJNE A, #BUTTON_5, STATE_COMPUTE_RESULT_NOT_BUTTON_5
    mov arg1_el, #5h
    lcall FORM_ARG_1
    mov bte, #'5'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_5:
    CJNE A, #BUTTON_6, STATE_COMPUTE_RESULT_NOT_BUTTON_6
    mov arg1_el, #6h
    lcall FORM_ARG_1
    mov bte, #'6'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_6:
    CJNE A, #BUTTON_7, STATE_COMPUTE_RESULT_NOT_BUTTON_7
    mov arg1_el, #7h
    lcall FORM_ARG_1
    mov bte, #'7'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_7:
    CJNE A, #BUTTON_8, STATE_COMPUTE_RESULT_NOT_BUTTON_8
    mov arg1_el, #8h
    lcall FORM_ARG_1
    mov bte, #'8'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_8:
    CJNE A, #BUTTON_9, STATE_COMPUTE_RESULT_NOT_BUTTON_9
    mov arg1_el, #9h
    lcall FORM_ARG_1
    mov bte, #'9'
    lcall send_data
    mov state, #STATE_FIRST_ARG
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_9:
    CJNE A, #BUTTON_CLEAR, STATE_COMPUTE_RESULT_NOT_BUTTON_CLEAR
    mov state, #STATE_START
    lcall CLEAR_ALL
    ret

    STATE_COMPUTE_RESULT_NOT_BUTTON_CLEAR: ; не нажата ни одна подходящая кнопка
    mov state, #STATE_ERROR
    lcall print_error_message
    ret
; --- --- --- STATE_COMPUTE_RESULT_HANDLER --- --- --- END


; --- --- --- STATE_OVERFLOW_HANDLER --- --- --- START
STATE_OVERFLOW_HANDLER:
    CJNE A, #BUTTON_CLEAR, STATE_OVERFLOW_NOT_BUTTON_CLEAR
    mov state, #STATE_START
    lcall CLEAR_ALL
    ret

    STATE_OVERFLOW_NOT_BUTTON_CLEAR: ; не нажата ни одна подходящая кнопка
    mov state, #STATE_ERROR
    lcall print_error_message
    ret
; --- --- --- STATE_OVERFLOW_HANDLER --- --- --- END


FORM_ARG_1:
    MOV A, arg1 ; загрузка arg1 -> ACC
    MOV B, #0Ah ; загружаем множитель 10
    MUL AB
    JB OV, FORM_ARG_1_OVERFLOW
    ADD A, arg1_el
    JB OV, FORM_ARG_1_OVERFLOW
    ; если ничего не переполнилось
    MOV arg1, A
    ret
    FORM_ARG_1_OVERFLOW:
    ; переходим в состояние переполнения
    MOV state, #STATE_OVERFLOW
    lcall clear_display
    lcall print_overflow_message
    ret

FORM_ARG_2:
    MOV A, arg2 ; загрузка arg1 -> ACC
    MOV B, #0Ah ; загружаем множитель 10
    MUL AB
    JB OV, FORM_ARG_2_OVERFLOW
    ADD A, arg2_el
    JB OV, FORM_ARG_2_OVERFLOW
    ; если ничего не переполнилось
    MOV arg2, A
    ret
    FORM_ARG_2_OVERFLOW:
    ; переходим в состояние переполнения
    MOV state, #STATE_OVERFLOW
    lcall clear_display
    lcall print_overflow_message
    ret

CLEAR_ALL:
    ; очищаем все переменные
    mov arg1, #0h
    clr first_arg_negative
    mov arg2, #0h
    clr second_arg_negative
    mov operation_sign, #0h
    ; очищаем дисплей
    lcall clear_display
    ret

clear_display:
    mov bte, #01h ; код очистки экрана
    ; выполняем отправку команды
    mov P2, bte  ; bte -> P2
    setb P3.4    ; E = 1
    clr P3.7     ; RW = 0 (ЖКИ читает)
    clr P3.5     ; RS = 0 (инф на шине есть команда)
    lcall indic_delay  ; вызываем ожидание
    clr P3.4     ; E = 0

    MOV R0, #41
    CLEAR_DISPLAY_LOOP:
        lcall indic_delay  ; вызываем ожидание
        DJNZ R0, CLEAR_DISPLAY_LOOP
    setb P3.4    ; E = 1
    ; очистка выполнена
    lcall indic_init ; сразу заново инициализируем дисплей
    ret

compute_result:
    ; проверяем нужно ли преобразовывать аргументы
    jnb first_arg_negative, compute_result_first_arg_not_negative ; переход если бит = 0 (нулю)
    lcall make_arg1_negative
    compute_result_first_arg_not_negative:

    jnb second_arg_negative, compute_result_second_arg_not_negative
    lcall make_arg2_negative
    compute_result_second_arg_not_negative:

    ; далее выполняем вычисления

    compute_result_perform_operation:
    ; Выполнение операции в зависимости от operation_sign
    mov A, operation_sign
    cjne A, #OPERATION_SIGN_MUL, compute_result_not_mul
    ; Выполнить умножение
    mov A, arg1
    mov B, arg2
    mul AB
    mov arg1, A
    sjmp compute_result_operation_end

    compute_result_not_mul:
    cjne A, #OPERATION_SIGN_DIV, compute_result_not_div
    ; Выполнить деление
    mov A, arg2
    cjne A, #0, compute_result_div_not_on_zero ; Проверка деления на ноль
    mov state, #STATE_ERROR
    lcall clear_display
    lcall print_error_message
    ret
    compute_result_div_not_on_zero:
    mov A, arg1
    mov B, arg2
    div ab
    mov arg1, A
    sjmp compute_result_operation_end

    compute_result_not_div:
    cjne A, #OPERATION_SIGN_SUB, compute_result_not_sub
    ; Выполнить вычитание
    mov A, arg1
    mov B, arg2
    clr C
    subb A, B
    mov arg1, A
    sjmp compute_result_operation_end

    compute_result_not_sub:
    cjne A, #OPERATION_SIGN_SUM, compute_result_operation_end
    ; Выполнить сложение
    mov A, arg1
    mov B, arg2
    add A, B
    mov arg1, A
    compute_result_operation_end:
    ; Проверка на переполнение
    jnb OV, compute_result_no_overflow
    ; Обработка переполнения и выход
    mov state, #STATE_OVERFLOW
    lcall clear_display
    lcall print_overflow_message
    ret
    compute_result_no_overflow:
    ret

make_arg1_negative:
    ; Загружаем значение arg1 в аккумулятор A
    mov A, arg1
    ; Инвертируем все биты
    cpl A
    ; Прибавляем 1 к инвертированному значению
    add A, #01h
    ; Сохраняем новое значение обратно в arg1
    mov arg1, A
    ret

make_arg2_negative:
    ; Загружаем значение arg1 в аккумулятор A
    mov A, arg2
    ; Инвертируем все биты
    cpl A
    ; Прибавляем 1 к инвертированному значению
    add A, #01h
    ; Сохраняем новое значение обратно в arg1
    mov arg2, A
    ret

print_result:
    mov A, arg1
    mov B, #100d
    div AB ; делим A на B
    CJNE A, #00h, print_result_100_not_null
    LJMP print_result_100_is_null
    print_result_100_not_null:
    add A, #'0' ; '0' - ASCII код нуля
    mov bte, A
    lcall send_data
    ; теперь получаем десятки
    print_result_100_is_null:
    mov A, B ; остаток переносим в аккамулятор
    mov B, #10d
    div AB
    CJNE A, #00h, print_result_10_not_null
    LJMP print_result_10_is_null
    print_result_10_not_null:
    add A, #'0'
    mov bte, A
    lcall send_data
    print_result_10_is_null:
    mov A, B ; остаток от деления на 10 переносим из B -> (в) A
    add A, #'0'
    mov bte, A
    lcall send_data
    ret

print_error_message:
    mov dptr, #0fd0h ;адрес, по которому расположены данные ;(см. конец программы)
    print_error_message_loop:
    clr A
    movc A, @A+DPTR
    mov bte, a ;передаваемый байт – код символа
    lcall send_data
    inc dptr
    mov a, dpl ;младший байт указателя данных
    cjne a, #0DBh, print_error_message_loop ;пока не выведены 11 символов 1ой строки
    ret

print_overflow_message:
    mov dptr, #0fe0h ;адрес, по которому расположены данные ;(см. конец программы)
    print_overflow_message_loop:
    clr A
    movc A, @A+DPTR
    mov bte, a ;передаваемый байт – код символа
    lcall send_data
    inc dptr
    mov a, dpl ;младший байт указателя данных
    cjne a, #0EBh, print_overflow_message_loop ;пока не выведены 11 символов 1ой строки
    ret

; инициализация ЖКИ
indic_init: 
    mov bte, #38h ;байт – команда
    lcall send_command ;вызов подпрограммы передачи в ЖКИ
    mov bte, #0Fh ;активация всех знакомест, включение курсора, курсор - квадратный
    lcall send_command
    mov bte, #06h ;режим автом. перемещения курсора
    lcall send_command
    mov bte, #80h ;установка адреса первого символа 
    ;(начинаем с 0-го символа первой строки)
    lcall send_command
    ret

; процедура передачи команды в ЖКИ
send_command:
    mov P2, bte  ; bte -> P2
    setb P3.4    ; E = 1
    clr P3.7     ; RW = 0 (ЖКИ читает)
    clr P3.5     ; RS = 0 (инф на шине есть команда)
    lcall indic_delay  ; вызываем ожидание
    clr P3.4     ; E = 0
    lcall indic_delay  ; вызываем ожидание
    setb P3.4    ; E = 1
    ret

; процедура предачи данных в ЖКИ
send_data:
    mov P2, bte  ; bte -> P2
    setb P3.4    ; E = 1
    clr P3.7     ; RW = 0 (ЖКИ читает)
    setb P3.5    ; RS = 1 (инф на шине есть данные)
    lcall indic_delay  ; вызываем ожидание
    clr P3.4     ; E = 0
    lcall indic_delay  ; вызываем ожидание
    setb P3.4    ; E = 1
    ret

indic_delay: ;подпрограмма задержки на 40мкс
    push ACC ;сохраняем аккумулятор в стеке
    mov A, #0Ah ; 40 = 2+2+1+A(1+2)+1+2+2
    m: dec A
    jnz m
    nop
    pop ACC ;восстанавливаем значение аккумулятора
    ret

; располагаем данные в памяти команд
org 0FD0h
error_message_string:
db '   error!  ' ; 11 bytes
org 0FE0h
overflow_message_string:
db ' overflow! ' ; 11 bytes

 END

