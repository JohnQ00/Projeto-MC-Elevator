;
; elevator.asm
;
; Authors: Igor Fontes, Danilo Fernandes e John Davi

; Definição das variáveis
.def current_floor = r17 ;indica a posição atual do elevador 
;current_floor = 1 representa o andar térreo
;current_floor = 2 representa o primeiro andar
;current_floor = 3 representa o segundo andar
;current_floor = 4 representa o terceiro andar

.def temp = r18;registrador temporário para auxiliar no controle do buzzer e do led
.def internal_floor_button = r19
.def external_button = r20 ;registrador responsável por setar o botão externo de chamada do elevador
.def display_1 = r21 ;display de 7 segmentos externo
.def display_2 = r22 ;display de 7 segmentos interno
.def timer_temp = r23
.def timer_aux = r24

define_timer:
	#define CLOCK 16.0e6
	#define DELAY 1.0e-3
	.equ PRESCALE = 0b100
	.equ PRESCALE_DIV = 256
	.equ WGM = 0b0100
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535
	.error "TOP is out of range"
	.endif

jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt

;buzzer e led como o bits menos significativos respectivamente. Exemplo: 0b10 representa o buzzer ativado e o led desligado
ldi temp, 0x00 ;configura PORTB como saída
out DDRB, temp

;setamos o último botão da PORTC como entrada para a chamada
ldi external_button, 0b11111110 ;configura o ultimo botão da PORTC como entrada
out DDRC, external_button

reset:
	timer:
		ldi timer_temp, high(TOP)
		sts OCR1AH, timer_temp
		ldi timer_temp, low(TOP)
		sts OCR1AL, timer_temp
		ldi timer_temp, ((WGM&0b11) << WGM10)
		sts TCCR1A, timer_temp
		ldi timer_temp, ((WGM >> 2) << WGM12)|(PRESCALE << CS10)
		sts TCCR1B, timer_temp

		lds r16, TIMSK1
		sbr r16, 1 <<OCIE1A
		sts TIMSK1, r16

		sei

	;apenas uma árvore de labels para cada andar, pensei em cada andar ser independente, mas isso pode mudar
	ground_floor:
		ldi current_floor, 0b00000001 ;seta o valor do registrador do andar atual
		rjmp external_panel

	first_floor:
		ldi current_floor, 0b00000010 ;seta o valor do registrador do andar atual
		rjmp external_panel

	second_floor:
		ldi current_floor, 0b00000011 ;seta o valor do registrador do andar atual
		rjmp external_panel

	third_floor:
		ldi current_floor, 0b00000110 ;seta o valor do registrador do andar atual
		rjmp external_panel

	;botões internos
	;botões para abrir, fechar, escolher o terceiro, segundo, primeiro ou térreo são representados pelos bits 5 a 0 da porta PORTD de entrada
	ldi internal_floor_button, 0x00
	out DDRD, internal_floor_button;configura PORTD como entrada

	external_panel:
		mov display_1, current_floor ;passando o valor do pavimento atual para o display de 7 segmentos do painel externo
		nop
		in external_button, PINC
		nop
		cpi external_button, 0b00000001
		breq internal_panel

		rjmp external_panel

	internal_panel:
		
		rjmp interruptions
		
		internal_panel_buttons:
			nop
			nop
			in internal_floor_button, PIND ;serve como o controlador interno do elevador como o Igor comentou acima
			nop
		
			cpi internal_floor_button, 0b00000001 
			breq ground_floor
	
			cpi internal_floor_button, 0b00000010
			breq first_floor
	
			cpi internal_floor_button, 0b00000011
			breq second_floor
	
			cpi internal_floor_button, 0b00000100
			breq third_floor

	end:
		rjmp internal_panel

OCI1A_Interrupt:
	push r16
	in r16, SREG
	push r16
	
	subi timer_aux, -1

	pop r16
	out SREG, r16
	pop r16
	reti

interruptions:

	floor:
		cpi timer_aux, 0b00001010
		breq on_led
		rjmp external_panel

	cpi (internal_floor_button | 0b10000000), 0b10000000
	brne internal_panel_buttons  

	buzzer:
		cpi timer_aux, 0b00000101
		breq on_buzzer
	
	led:
		cpi timer_aux, 0b00001010
		breq on_led

	rjmp internal_panel_buttons

buzzer_timer:
	;Quando as condições de interrupção forem atingidas (relacionadas à abertura da porta do elevador) 
	on_buzzer:
		subi temp, -1 ;seta o segundo bit menos significativo para 1 
		out PORTB, temp ;liga o bit do buzzer na PORTB
		rjmp off_buzzer
	
	off_buzzer:
		subi temp, 1 ;seta o segundo bit menos significativo para 0
		out PORTB, temp ;desliga o bit do buzzer na PORTB
		rjmp end

led_timer:
	on_led:
		subi temp, -2 ;seta o bit menos significativo para 1
		out PORTB, temp ;liga o bit do led na PORTB
		rjmp end
	
	off_led:
		subi temp, 2 ;seta o bit menos significativo para 0
		out PORTB, temp ;desliga o bit do led na PORTB
	
