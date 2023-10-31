# Notes
in chapter one they suggest that to be tested later, but we can add a binance mock 
account: https://testnet.binance.vision

I will use a rule of only read one link depth, meaning that I will not matter if a links goes to another link, I will 
read only the first link

# Links
## Chapter 1
[binance websocket documentation](https://github.com/binance/binance-spot-api-docs/blob/master/web-socket-streams.md)

# Extras
when using [vim](https://vi.stackexchange.com/questions/4307/multiple-cursors-at-desired-location), and we need to make a repeatable change, we should find a way to search the pattern and apply the change with the `.` command

 The magic formula in Vim is n.. A really cool workflow is:

* search for the place you want to make an edit with /pattern
* make your repeatable edit
* use n to go to the next place to edit
* use . to repeat the edit
* repeat the last two steps: You're the king of the world (or at least of edits)


# Chapters
## Chapter 1
Elixir is usually easy to understand, so when the documentation is ligth we must not be afraid of take a look of to the source code 

here we review the commands to handle some project organization like 
* `iex -S mix`: run the project in 'interactive' mode
* `mix deps.get`: bring dependencies from the mix file
* `mix format`: organize the project with a 'linter'
* `mix new streamer --sup`: creates a new project with a supervisor structure

## Chapter 2
when using the word `use` in a module we usually need to fullfill the contract, in
the case of the genserver `start_link/1` allow us to register a process  with a name

the trader needs to known
* what symbol to trade, this means like XRPUSDT which means i will change XRP to USDT
* placed buy order (if any)
* place sell order (if any)
* profit interval (what net profit % we would like to achieve when buying and selling the asset in one cycle)
* tick_size is how the smallest and biggest unit that we can 'divide' the 'symbol' for example, in dollars the minimal unit are cents, TODO: finish [reading](https://www.investopedia.com/terms/t/tick.asp), the tick size is a movement indicator, it can tell us if the transaction occurred at a higher or lower price

* the decimal module will allow us to overcome problems with the precision

---

![trade_cycle](resources/image.png)
the trader will have 3 states:
* without orders (sell or buy)
* with a sell order placed 
* with a buy order placed 
