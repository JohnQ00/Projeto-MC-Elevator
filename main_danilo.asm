;
; AssemblerApplication7.asm
;
.def temp = r16
.def position = r17 ; valor inteiro indicando a posicao atual do elevador
.def requests = r18 ; recebe requisições internas (quatro bits mais significativos) e externas (quatro bits menos significativos) na forma de bits 'setados' (Ex.: 0b01000001 indica uma requisicao externa no térreo e uma requisicao interna para o 2º andar)
.def control = r19 ; variavel de utilizada para buscar iterativamente o proximo andar de destino
.def target = r20 ; valor inteiro indicando o proximo andar de destino
.def state = r21 ; contem as flags que indicam se o led e o buzzer estão ligados
.def step = r22 ; indica se o elevador deve subir ou descer
.def count_timer = r23

;Configuracao do Timer
#define CLOCK 32.0e6
#define DELAY 5.0e-6 ; segundos (5us)
.equ PRESCALE = 0b001 ; sem prescale
.equ PRESCALE_DIV = 1
.equ WGM = 0b0100
.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
.if TOP > 65535
.error "top IS OUT OF RANGE"
.endif

;Interrupt Vector Table (IVT)
jmp reset
jmp close_door ; int0
jmp request ; int1
.org OC1Aaddr
jmp timer_interrupt

close_door:
	ldi state, 0 ; Desliga o led e o buzzer
	out PORTD, state ; Carrega o estado na saída para o usuario
	reti

request:
	in requests, PINB ; Carrega os botoes pressionados em requests
	reti

timer_interrupt:
	push temp
	in temp, SREG
	push temp

	subi count_timer, 1

	pop temp
	out SREG, temp
	pop temp
	reti

reset:
	;inicializa a pilha
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	;configure INT0 AND INT1 sense
	ldi temp, (0b11 << ISC10) | (0b11 << ISC00) ;positive edge triggers
	sts EICRA, temp
	;enable int0 and int1
	ldi temp, (1 << INT0) | (1 << INT1)
	out EIMSK, temp

	; inicializa os dois bits menos significativos de PORTB como saída (Buzzer e Led)
	ldi temp, $03
	out DDRD, temp

	;habilita a interrupção global
	sei 

main_loop:
	cpi requests, 0 ; Verifica se há requisicoes a serem atendidas
	brne go_next_floor
	rjmp main_loop

go_next_floor:
	ldi control, 0b10000000
	ldi target, 8
	rcall get_next_floor

	ldi step, 1
	mov temp, target
	sub temp, position
	tst temp
	breq down

	rjmp move_to_target

	down:
		neg step
		rjmp move_to_target

get_next_floor:
	mov temp, requests
	and temp, control

	lsr control
	dec target
	
	cpi temp, 0
	breq get_next_floor

	lsl control

	mov temp, target
	andi temp, 0b00001100
	cpi temp, 0
	brne sub4
	ret

	sub4:
		subi target, 4
		ret

move_to_target:
	
	ldi count_timer, 2
	rcall timer

	add position, step
	cp position, target
	brne move_to_target

	mov temp, control
; caso control = 01000000 e requests = 01000100	
	lsr temp
	lsr temp
	lsr temp
	lsr temp ; temp = 00000100

	or control, temp ; control = 01000100
	ldi temp, $FF
	eor control, temp
	;control = 10111011

	and requests, control ; requests = 00000000

	ldi state, 1
	out PORTD, state ; light on, baby!
	
	ldi count_timer, 1
	rcall timer

	cpi state, 0
	brne buzzing
	rjmp main_loop

	buzzing:
		ldi state, 3
		out PORTD, state

		ldi count_timer, 1
		rcall timer

		ldi state, 0
		out PORTD, state
		rjmp main_loop

timer:
	; On MEGA series, write high byte of 16-bit timer register first
	ldi temp, high(TOP) ; initialize compare value (TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp
	ldi temp, ((WGM&0b11) << WGM10) ; lower 2 bits of WGM
	; WGM&0b11 = 0b0100 & 0b0011 = 0b0000
	sts TCCR1A, temp
	; upper 2 bits of WGM and clock select
	ldi temp, ((WGM >> 2) << WGM12)|(PRESCALE << CS10)
	; WGM >> 2 = 0b0100 >> 2 = 0b0001
	; (WGM >> 2) << WGM12 = (0b0001 << 3) = 0b00001000
	; (PRESCALE << CS10) = 0b100 << 0 = 0b100
	; 0b00001000 | 0b100 = 0b00001100
	sts TCCR1B, temp

	; ativa a interrupção ligada a OCR1A
	lds temp, TIMSK1
	sbr temp, 1 << OCIE1A
	sts TIMSK1, temp

	cpi count_timer, 0
	brne timer

	ret		
