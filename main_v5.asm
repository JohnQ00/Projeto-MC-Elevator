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
.def timer_temp = r23 ;serve para setar o valor do TOP quando definimos o tempo de contagem
.def timer_aux = r24 ;ajuda a contar cada 1ms que passa para conseguirmos interromper no momento adequado para cada interrupção
.def aux = r25

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

		;botões internos
		;botões para abrir, fechar, escolher o terceiro, segundo, primeiro ou térreo são representados pelos bits 5 a 0 da porta PORTD de entrada
		ldi internal_floor_button, 0x00
		out DDRD, internal_floor_button;configura PORTD como entrada

		external_panel:
			;Aqui temos a representação do botão para chamar o elevador
			;[0|0|0|0|0|0|0|0] cada casa da direita para a esquerda conta como um andar, logo, 

			;[0|0|0|0|0|0|0|1] significa um chamado do térreo
			;[0|0|0|0|0|0|1|0] significa um chamado do primeiro andar
			;[0|0|0|0|0|1|0|0] significa um chamado do segundo andar
			;[0|0|0|0|1|0|0|0] significa um chamado do terceiro andar

			mov display_1, current_floor ;passando o valor do pavimento atual para o display de 7 segmentos do painel externo
			nop
			in external_button, PINC
			nop

			mov aux, external_button

			andi aux, 0b00001000
			bst aux, 3
			brts third_floor

			mov aux, external_button

			andi aux, 0b00000100
			bst aux, 2
			brts second_floor

			mov aux, external_button

			andi aux, 0b00000010
			bst aux, 1
			brts first_floor

			mov aux, external_button

			andi aux, 0b00000001
			bst aux, 0
			brts ground_floor

			rjmp external_panel

	;apenas uma árvore de labels para cada andar, pensei em cada andar ser independente, mas isso pode mudar
	ground_floor:
		ldi current_floor, 0b00000001 ;seta o valor do registrador do andar atual
		bst external_button, 7
		rjmp internal_panel

	first_floor:
		ldi current_floor, 0b00000010 ;seta o valor do registrador do andar atual
		bst external_button, 7
		rjmp internal_panel

	second_floor:
		ldi current_floor, 0b00000011 ;seta o valor do registrador do andar atual
		bst external_button, 7
		rjmp internal_panel

	third_floor:
		ldi current_floor, 0b00000110 ;seta o valor do registrador do andar atual
		bst external_button, 7
		rjmp internal_panel

	

	internal_panel:
		;Aqui que colocamos o andar
		;[0|0|0|0|0|0|0|0] botões
		;[0|0|0|0|1|1|1|1] 4 primeiros para os andares
		;[0|0|1|0|0|0|0|0] fechar a porta
		;a ausência do fechamento da porta indica que a porta está aberta

		nop ;quando setar o valor no PIND já pode dar play no botão verde daqui
		nop
		in internal_floor_button, PIND ;serve como o controlador interno do elevador como o Igor comentou acima
		nop 

		rjmp interruptions

		advancing_floor:
			cpi internal_floor_button, 0b100001 
			breq ground_floor
	
			cpi internal_floor_button, 0b100010
			breq first_floor
	
			cpi internal_floor_button, 0b100100
			breq second_floor
	
			cpi internal_floor_button, 0b101000
			breq third_floor

			out PORTD, internal_floor_button
			
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
	; [0|0|1|0|0|0|0|0] porta fechada
	andi internal_floor_button, 0b101111 ; Do bitwise or between registers
	bst internal_floor_button, 5
	brts floor ; [0|0|0|1|0|0|0|0] porta aberta

	alerts:
			; [0|0|0|1|0|0|0|0] porta aberta 
			buzzer:
				cpi timer_aux, 0b00000101
				breq on_buzzer
	
			led:
				cpi timer_aux, 0b00001010
				breq on_led

		rjmp internal_panel

	floor:
		cpi timer_aux, 0b00001010
		breq advance_floor

	rjmp internal_panel
;Quando as condições de interrupção forem atingidas (relacionadas à abertura da porta do elevador) 
on_buzzer:
	subi temp, -1 ;seta o segundo bit menos significativo para 1 
	out PORTB, temp ;liga o bit do buzzer na PORTB
	cpi internal_floor_button, 0b100000 
	breq off_buzzer ; Interrompe aqui para testar o fluxo do buzzer
	rjmp end
	
off_buzzer:
	subi temp, 1 ;seta o segundo bit menos significativo para 0
	out PORTB, temp ;desliga o bit do buzzer na PORTB
	rjmp end

on_led:
	subi temp, -2 ;seta o bit menos significativo para 1
	out PORTB, temp ;liga o bit do led na PORTB
	rjmp end ; Interrompe aqui para testar o fluxo do led
	
off_led:
	subi temp, 2 ;seta o bit menos significativo para 0
	out PORTB, temp ;desliga o bit do led na PORTB
	
advance_floor:
	bst internal_floor_button, 7
	nop
	rjmp advancing_floor ; Interrompe aqui para testar o fluxo da mudança de andar