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
Elixir is usually easy to understand, so when the documentation is light we must not be afraid of take a look of to the source code 

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

in the mix.exs of the root directory, putting a dependency there does not mean that will be available for the apps inside the umbrella, configuration is needed, that said, there are some packages 


* new_trader: does not have any open order cause no `buy_order` is there
* buy_order_placed: arrives a order_id matching our buy_order_id
* sell_order_placed: arrives a order_id matching our sell_order_id, here the trader can exit

the function `calculate_sell_price/3` works in the next way:
  * first the fee is harcoded and is equivalent to 0.1%
  * `original_price` is the buy price adding it the fee.
  * we grow the `original_price` with the `profit_interval` giving us the result of `net_target_price`
  * thus there is commision for selling we need to add a fee to the `net_target_price` giving us the result of the `gross_target_price`
  * we need to normalze the price since binance wont accept prices that are not divisible by the symbols.

I have tested using the binance [testnet](https://testnet.binance.vision) and looks like it worked,

I am comparing my branch with the remote with franton to see differences
  

