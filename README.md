**Objetivo**

Implementar em assembly do AVR um código que simule o funcionamento de um elevador para um prédio de 3 andares (térreo + 3).

**Equipamentos**

1x Display 7 segmentos para mostrar onde está o elevador
4x Botão para chamar elevador (botão nos andares)
1x Display 7 segmentos para mostrar onde está o elevador 
4x botões para definir para qual andar ir (botão dentro do elevador)
1x botão para abrir a porta
1x botão para fechar a porta
1x Buzzer para avisar que a porta esta aberta
1x Led verde para indicar abertura da porta
Simulação dos equipamentos:
Display de 7 segmentos deverá ser simulado como um valor em um registrador.
Botão, Buzzer e Led deverão ser simulado como um bit em uma das portas de E/S.

**Requisitos**
- Priorizar os andares mais altos caso tenha duas chamadas
Exemplo: Se estiver no térreo subindo para o 2º andar, não deve parar no 1º andar, mesmo que o botão que fica no primeiro andar tenha sido pressionado antes de o carro do elevador passar pelo 1° andar.
Obs: Essa prioridade não acontece para os botões dentro do elevador.

- Se a porta do elevador ficar aberta por 5 microssegundos, toca-se o Buzzer 
- Se a porta do elevador ficar aberta por 10 microssegundos  , deve ser fechada
- O elevador leva 10 microssegundos   de um andar para o outro
- Deve-se utilizar os Timers do AVR para definir os tempos
- Deve-se utilizar interrupção ao invés de verificação de flag
Obs: Esse tempo de microssegundos é para facilitar a simulação, não é um tempo prático.

**Etapas**
1. Definir a máquina de estados que representa a modelagem do funcionamento do elevador;
3. Implementar código que simule o comportamento do elevador;
4. Gravar apresentação que comprove o funcionamento do código por meio de simulação do Microchip studio.

**Regras Gerais**
- Grupos com três alunos
- Código assembly muito bem comentado!!
- Todos os integrantes do grupo receberão uma nota de 0 a 5 de acordo com o funcionamento do projeto como um todo.
- Cada aluno receberá uma nota de 0 a 5 de acordo com a sua explicação individual. (Cada integrante deve falar algo no vídeo)

**Roteiro Apresentação**
1. Apresentação da máquina de estados destacando os tempos de cada estado;
2. Explicação do código em assembly;
3. Simulação do código no Microchop Studio comprovando o correto funcionamento de cada estado do elevador;
