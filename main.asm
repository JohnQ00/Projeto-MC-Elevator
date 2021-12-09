;
; elevator.asm
;
; Authors: Igor Fontes, Danilo Fernandes e John Davi

; Definição das variáveis
.def pav_atual = r16 ;indica a posição atual do elevador 
.def temp = r17; registrador temporário para auxiliar no controle do buzzer e do led

;buzzer e led como o bits menos significativos respectivamente. Exemplo: 0b10 representa o buzzer ativado e o led desligado
ldi temp, 0x00 ;configura PORTB como saída
out DDRB, temp

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
;botões para abrir, fechar, escolher o terceiro, segundo, primeiro ou térreo são representados pelos bits 5 a 0 da porta PORTD de entrada
ldi r18, 0x00
out DDRD, r18 ;configura PORTD como entrada

press_button:
	in r18, PIND
	out PORTD, r18 ; TO DO: a saída em PORTB está só piscando aparentemente, mas por causa do tempo de execução não consegui verificar ao certo
	; TO DO: falta ver o que faz com mais de uma chamada do elevador
	cpi r18, 0b10000 ; se bit 4 do r18 == 1, abra a porta
	breq on_led
	; TO DO: o que acontece depois de on_led ser executado? depois que um botão é pressionado precisa setar PIND para 0 de novo?
	cpi r18, 0b100000; se bit 5 do r18 == 1, fecha a porta
	breq off_led
	;lds r16, r18 ;atualiza pav_atual com a chamada do r18 (no caso de nenhum botão de abrir ou fechar a porta ser pressionado)

end:
	rjmp end
