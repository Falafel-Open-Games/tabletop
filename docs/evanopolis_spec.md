# 📘 Evanópolis – Especificação Oficial do Jogo (Versão Consolidada)

## 1. Visão Geral

Evanópolis é um jogo de tabuleiro digital, multiplayer (2–6 jogadores), baseado em:

- Economia inspirada em mineração de Bitcoin
- Compra e desenvolvimento de propriedades
- Construção de infraestrutura (containers, máquinas)
- Uso de cartas de evento (Suerte e Destino)
- Jackpot progressivo global
- Competição por um grande prêmio final
- Sistema de referidos
- Queima automática de tokens EVA
- Salas com diferentes valores de entrada (ticket)

---

## 2. Modelo de Salas e Lobby

### 2.1 Tela Inicial

- Criar Sala
- Entrar em Sala Aleatória
- Lista de salas ativas contendo:
  - Valor do ticket (0.1, 0.5, 1, 5, 10, 25, 50 EVA)
  - Jogadores presentes
  - Capacidade total (4–6)

### 2.2 Criação de Sala

- Sistema gera ID da sala
- Host pode convidar jogadores via link
- Início manual quando houver ≥ 2 jogadores
- Todos devem clicar “Pronto” para iniciar

### 2.3 Entrada Rápida

- Jogador entra automaticamente em qualquer sala com vaga

### 2.4 Requisitos Técnicos

- Estado da sala mantido no servidor
- Jogadores entram com saldo inicial = ticket
- Jogo só inicia quando todos confirmam “Pronto”

---

## 3. Tabuleiro (Estrutura Técnica)

O tabuleiro possui **36 casas** em um array circular:

- 24 propriedades
- 6 propriedades especiais
- 2 Suerte
- 2 Destino
- 1 Cárcel
- 1 Salida (GO)

Formato octogonal conforme imagem enviada.

---

## 4. Cidades e Valores

| Cidade            | Valor Base |
|------------------|------------|
| Caracas          | 1 EVA      |
| Assunção         | 2 EVA      |
| Ciudad del Este  | 2 EVA      |
| Minsk            | 3 EVA      |
| Sibéria          | 3 EVA      |
| Texas            | 4 EVA      |

---

## 5. Infraestrutura por Terreno

Cada terreno permite:

- 1 container hidro (2 EVA)
- 4 lotes de 50 máquinas (1 EVA cada)

### Investimento Máximo

```
valorTerreno + 6 EVA
```

### Exemplo

Terreno Caracas full:

- 1 + 2 + 4 = 7 EVA investidos
- Renda Base = 7 EVA

---

## 6. Monopólio

Monopólio ocorre quando:

- Jogador possui os 4 terrenos da cidade
- Todos no nível 5

### Efeito

```
RendaFinal = RendaBase × 2
```

Aplicado antes de bônus globais/locais.

---

## 7. Propriedades Especiais

| Especial         | Custo | Efeito |
|------------------|-------|--------|
| Importadora 1    | 5 EVA | Permite comprar equipamentos; 10% de comissão |
| Subestação 1     | 6 EVA | +10% renda global |
| Oficina Própria  | 8 EVA | +10% renda na cidade |
| Importadora 2    | 5 EVA | Com Importadora 1 → 20% comissões |
| Subestação 2     | 6 EVA | Com Subestação 1 → +30% renda global |
| Cooling Plant    | 10 EVA| +10% renda na cidade |

### Fórmula Final

```
RendaFinal = RendaBase × bonusGlobal × bonusCidade
```

---

## 8. Turno, Movimento e SALIDA

### A cada turno:

1. Jogador lança 2 dados
2. Move o total
3. Executa ação da casa (comprar, pagar, carta etc.)

### Passar pela SALIDA

- +2 EVA
- +1 tiro grátis de jackpot

### Cair exatamente na SALIDA

- +1 EVA adicional

---

## 9. Prisão (Cárcel)

### Consequências

Jogador **não se move**, mas pode:

- Cobrar renda
- Comprar tickets de jackpot
- Votar em aumento de capital
- Receber cartas positivas

### Como sair

#### A) Pagar 3 EVA

#### B) Tirar duplo em até 3 turnos  
Após 3 falhas → paga 3 EVA obrigatoriamente.

---

## 10. Carta Especial de Prisão

**Inspeção Legal Rigorosa (Destino)**

Envia jogador diretamente à prisão.

Para sair:

- paga 3 EVA, ou  
- tira um duplo em até 3 turnos

Nenhuma carta cancela.

---

## 11. Sistema Econômico do Jogo

Toda compra feita ao banco:

- Terreno
- Especial
- Container
- Máquinas

### Distribuição

```
10% → Jackpot
30% → Referidos
10% → Queima
50% → Fundo Final
```

Banco não retém nada.

---

## 12. Fundo Final

Distribuição ao fim do jogo:

- 1º → 70%
- 2º → 20%
- 3º → 10%
- Outros → 0

Escalonável por sala.

---

## 13. Jackpot Progressivo

### Entradas

- 10% de compras
- Passar pela SALIDA
- Tickets de jackpot
- 0,5% de todas rendas (pago pelo banco)
- Cartas negativas
- Todas as salas ativas

### Mecânica

- 1 tiro grátis ao passar pela SALIDA
- Tickets adicionais podem ser comprados
- Chance definida por curva logística
- A chance aumenta conforme jackpot cresce

### Quando ganho

- 90% para jogador
- 10% como semente
- Jackpot reinicia

---

## 14. Cartas Suerte e Destino

Cada baralho tem 20 cartas:

- 8 positivas
- 7 negativas diretas
- 5 negativas entre jogadores

Valores de 1 a 10 EVA.

---

## 15. Hipotecas

- Banco empresta 60% do valor do terreno
- Para recuperar → pagar 70%
- Terreno hipotecado não gera renda
- Máquinas devem ser vendidas antes de hipotecar

---

## 16. Aumento de Capital

Quando o 4º jogador completa a 1ª volta:

- Abre votação global
- Se 100% aprovarem → cada jogador deposita novamente o ticket
- Liquidez é dobrada
- Se 1 recusar → não ocorre

---

## 17. Final do Jogo

Jogo termina quando:

- Um jogador quebra
- Turnos pré-definidos acabam
- Tempo limite expira
- Jogadores votam por encerrar

Premiação vem do Fundo Final.

---

## 18. Estrutura Técnica para Implementação

### Cliente

- Godot/Web
- Renderização do tabuleiro
- Interface de compra, cartas, renda, jackpot
- Comunicação com servidor (HTTP/WebSocket)

### Servidor

- Autoridade do estado do jogo
- Controle de turnos
- Aplicar fórmulas de renda
- Jackpot global
- Persistência completa
- Auditoria de eventos

### Persistência

- Estado do jogo
- Propriedades
- Jackpot
- Fundo Final
- Histórico de cartas e ações
