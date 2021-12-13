;
; elevator.asm
;
; Authors: Igor Fontes, Danilo Fernandes e John Davi

; Definição das variáveis
.def current_floor = r16 ;indica a posição atual do elevador 
; current_floor = 0 representa o andar térreo
; current_floor = 1 representa o primeiro andar
; current_floor = 2 representa o segundo andar
; current_floor = 3 representa o terceiro andar

.def temp = r17; registrador temporário para auxiliar no controle do buzzer e do led
.def internal_floor_button = r18
.def external_button = r19 ; registrador responsável por setar o botão externo de chamada do elevador
.def display_1 = r20 ; display de 7 segmentos externo
.def display_2 = r21 ; display de 7 segmentos interno

;buzzer e led como o bits menos significativos respectivamente. Exemplo: 0b10 representa o buzzer ativado e o led desligado
ldi temp, 0x00 ;configura PORTB como saída
out DDRB, temp

;setamos o último botão da PORTC como entrada para a chamada
ldi external_button, 0b11111110 ; configura o ultimo botão da PORTC como entrada
out DDRC, external_button

external_panel:
	mov display_1, current_floor ; passando o valor do pavimento atual para o display de 7 segmentos do painel externo
	in external_button, PINC
	cpi external_button, 0b00000001
	breq press_button
	rjmp external_panel

; apenas uma árvore de labels para cada andar, pensei em cada andar ser independente, mas isso pode mudar
ground_floor:
	ldi current_floor, 0b00000001 ; seta o valor do registrador do andar atual
	rjmp external_panel

first_floor:
	ldi current_floor, 0b00000010 ; seta o valor do registrador do andar atual
	rjmp external_panel

second_floor:
	ldi current_floor, 0b00000011 ; seta o valor do registrador do andar atual
	rjmp external_panel

third_floor:
	ldi current_floor, 0b00000110 ; seta o valor do registrador do andar atual
	rjmp external_panel

; Quando as condições de interrupção forem atingidas (relacionadas à abertura da porta do elevador) 
on_buzzer:
	subi temp, -2; seta o segundo bit menos significativo para 1 
	out PORTB, temp ;liga o bit do buzzer na PORTB
	rjmp end
	
off_buzzer:
	subi temp, 2; seta o segundo bit menos significativo para 0
	out PORTB, temp ;desliga o bit do buzzer na PORTB
	
on_led:
	subi temp, -1; seta o bit menos significativo para 1
	out PORTB, temp ;liga o bit do led na PORTB
	
off_led:
	subi temp, 1; seta o bit menos significativo para 0
	out PORTB, temp ;desliga o bit do led na PORTB

; botões internos
; botões para abrir, fechar, escolher o terceiro, segundo, primeiro ou térreo são representados pelos bits 5 a 0 da porta PORTD de entrada
ldi internal_floor_button, 0x00
out DDRD, internal_floor_button ;configura PORTD como entrada

press_button:
	in internal_floor_button, PIND ; serve como o controlador interno do elevador como o Igor comentou acima
	; TO DO: falta trabalhar a dinâmica dos andares
	cpi internal_floor_button, 0b00000001 
	breq ground_floor
	
	cpi internal_floor_button, 0b00000010
	breq first_floor
	
	cpi internal_floor_button, 0b00000111
	breq second_floor
	
	cpi internal_floor_button, 0b00000100
	breq third_floor

	out PORTD, internal_floor_button ; TO DO: a saída em PORTB está só piscando aparentemente, mas por causa do tempo de execução não consegui verificar ao certo
	; TO DO: falta ver o que faz com mais de uma chamada do elevador
	cpi internal_floor_button, 0b10000 ; se bit 4 do r18 == 1, abra a porta
	breq on_led
	; TO DO: o que acontece depois de on_led ser executado? depois que um botão é pressionado precisa setar PIND para 0 de novo?
	cpi internal_floor_button, 0b100000; se bit 5 do r18 == 1, fecha a porta
	breq off_led
	;lds r16, r18 ;atualiza pav_atual com a chamada do r18 (no caso de nenhum botão de abrir ou fechar a porta ser pressionado)

end:
	rjmp external_panel
