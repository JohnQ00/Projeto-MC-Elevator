;
; AssemblerApplication7.asm
;
.def temp = r16
.def position = r17 ; valor inteiro indicando a posicao atual do elevador
.def requests = r18 ; recebe requisições internas (quatro bits mais significativos) e externas (quatro bits menos significativos) na forma de bits 'setados' (Ex.: 0b01000001 indica uma requisicao externa no térreo e uma requisicao interna para o 2º andar)
.def control = r19 ; variavel utilizada para buscar iterativamente o proximo andar de destino
.def target = r20 ; valor inteiro indicando o proximo andar de destino
.def state = r21 ; contem as flags que indicam se o led e o buzzer estão ligados
.def step = r22 ; indica se o elevador deve subir ou descer
.def count_timer = r23 ; auxilia na identificação da passagem de 5 ou 10 ms para ocorrência de algum evento, como o acionamento do buzzer 

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

	subi count_timer, 1 ; decrementa 1 em count_timer para indicar ,por meio da entrada na interrupção, a passagem de 1 ms

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
	brne go_next_floor ; caso haja requisições, executa go_next_floor
	rjmp main_loop

go_next_floor:
	ldi control, 0b10000000 ; inicia a variável de busca de requisições com o bit mais significativo em 1 para atender requisições na ordem de prioridade de chamada 
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
	and temp, control ; detecta os bits setados em 1 em 'requests' da esquerda para a direita usando 'control' como indicador usando 'and' 

	lsr control ; desloca um bit de 'control' para a direita
	dec target ; decrementa 1 em 'target' para indicar que não havia requisição em determinado bit
	
	cpi temp, 0 ; verifica se o bit indicado em 'control' coincide com alguma requisição após a operação de 'and' com requests
	breq get_next_floor ; volta para get_next_floor para procurar a requisição a ser atendida. Caso contrário, prossegue com a execução da requisição.
  
	lsl control ; shift bit de 1 bit para a esquerda para retornar à requisição

	mov temp, target ; salva o andar do 'target' em 'temp'
	andi temp, 0b00001100 ; CONFUSO SOBRE ISSO, PQ ESSE NUMERO
	cpi temp, 0
	brne sub4
	ret

	sub4:
		subi target, 4
		ret

move_to_target:

	; Aqui é feita a soma no contador de tempo, ou seja, quantas interrupções devem ser 
	; contabilizadas para o programa ser interrompido
	ldi count_timer, 2 
	rcall timer ; Aqui é feita a chamada para o contador de tempo

	; Position indica o andar que o elevador está e step indica se o elevador deve subir ou descer através de um bit
	add position, step
	; Após isso é comparado o valor do andar do elevador, position, com o andar que é alvo, target, 
	; Caso não sejam os mesmos o loop continua, caso contrário, o fluxo de movimentação do elevador continua
	cp position, target
	brne move_to_target

	; Agora que o elevador chegou no andar que deveria estar, as outras requisições externas e internas são checadas

	; A variável control, que recebe o valor do bit mais significativo e é responsável 
	; por ordenar as requisições por altura e entre externas e internas para o mesmo andar
	mov temp, control
	; Caso control = 01000000 e requests = 01000100, temos temp = 01000000
	lsr temp ; => 00100000
	lsr temp ; => 00010000
	lsr temp ; => 00001000
	lsr temp ; => 00000100

	; Quando fazemos o OR entre control e temp, temos novamente 
	or control, temp ; control OR temp = 01000000 OR 00000100 = 01000100
	ldi temp, $FF ; Adicionando em temp = 11111111
	eor control, temp ; control EOR temp = 01000100 EOR 11111111 = 10111011

	and requests, control ; requests AND control = 01000100 AND 10111011 = 00000000
	; Dessa forma, a gente confirma que todas as requisições foram atendidas em sua devida ordem

	ldi state, 1 ; O registrador state é responsável por indicar se o LED e o buzzer estão ativos
	out PORTD, state ; light on, baby! ; Aqui é transferido o valor de state para indicar que o LED está aceso
	
	ldi count_timer, 1 ; Aqui o tempo de 5us deve ser contado, ou seja, deve-se entrar uma vez na interrupção para contar os 5us
	rcall timer

	cpi state, 0 ; Aqui ele checa se a porta aberta até os 5us foi fechada, se não for fechada, é acionado o buzzer
	brne buzzing
	rjmp main_loop

	buzzing:
		ldi state, 3 ; Em state é carregado o valor 3 (00000011) para indicar que o LED está aceso e o buzzer está soando
		out PORTD, state ; É exibido nos pinos de saída valores para o LED e o buzzer ativos

		ldi count_timer, 1 ; Aqui é feita outra checagem de tempo, ou seja, se entrou mais uma vez na interrupção e foi contado
		; mais 5 microssegundos significa que a porta deve ser fechada
		rcall timer

		ldi state, 0 ; Como state carrega o estado da porta, ao colocarmos o valor 0 dizemos que a porta foi fechada 
		; e consequentemente o buzzer e o LED foram desligados
		out PORTD, state ; Aqui o registrador de estado da porta, LED e buzzer é exibido no pino de saída
		rjmp main_loop ; Voltamos aqui para o loop principal, pois as requisições foram atendidas e o elevador está onde deve estar

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
