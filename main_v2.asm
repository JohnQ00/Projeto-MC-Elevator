;
; AssemblerApplication7.asm
;
.def temp = r16
.def leds = r17
.def req_ext = r18 ; recebe requisições externas
.cseg

jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt

OCI1A_Interrupt:
	push r16
	in r16, SREG
	push r16
	; inicio da tarefa de interrupcao
	in r18, (PINB << 4) ;coloca os 4 bits mais significativos para a chamada
	;CONTINUA
	; fim da tarefa de interrupcao
	pop r16
	out SREG, r16
	pop r16
	reti

reset:
	ldi r18, 0 ;inicializa req_ext
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	ldi temp, $FF
	out DDRB, temp
	ldi leds, $AA
	out PORTB, leds

	#define CLOCK 16.0e6
	#define DELAY 1.0e-3 ;1ms
	.equ PRESCALE = 0b100
	.equ PRESCALE_DIV = 256
	.equ WGM = 0b0100
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535
	.error "top IS OUT OF RANGE"
	.endif

	ldi  temp, high(TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp
	ldi temp, ((WGM&0b11) << WGM10)
	sts TCCR1A, temp
	ldi temp, ((WGM >> 2) << WGM12)|(PRESCALE << CS10)
	sts TCCR1B, temp

	; ativa a interrupção ligada a OCR1A
	lds r16, TIMSK1
	sbr r16, 1 <<OCIE1A
	sts TIMSK1, r16

	;habilita a interrupção global
	sei 
	main_lp:
		rjmp main_lp
