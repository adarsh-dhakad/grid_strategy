//+------------------------------------------------------------------+
//|                                                  DemoGridBot.mq5 |
//|                                    Copyright 2024, Demo Engineer |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Demo Engineer"
#property link      ""
#property version   "1.00"
#include <Trade\Trade.mqh> // Include the standard trade library

//--- Input Parameters (Settings you can change)
input double   InitialLot     = 0.01;        // Starting Lot Size (Step 1)
input double   LotMultiplier  = 0.01;         // Multiply Lot by this (2.0 = Double)
input int      GridStep       = 1000;        // Drop in Points ($10 Drop on Gold = 1000 points)
input double   TakeProfitUSD  = 10;         // Close ALL trades when total profit > $5.00
input int      MaxOrders      = 200;          // Safety: Stop buying after this many orders


//--- Global Variables
CTrade trade;
int magicNumber = 123456;

#include <Trade/Trade.mqh>

CTrade *Trade;

input int Slippage = 2;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(magicNumber);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   int openOrders = CountBuyPositions(); // Assuming you have this helper function
   double currentProfit = GetTotalProfit();

// 3. The Fix: Only check profit IF we have open orders
   if(currentProfit >= TakeProfitUSD)
     {
      ClosePositions();
      return; // Wait for next tick
     }

// 3. LOGIC: If NO trades, open the first one
   if(openOrders == 0)
     {
      trade.Buy(InitialLot, Symbol(), 0, 0, 0, "First Trade");
     }

// 4. LOGIC: If we HAVE trades, check if we need to buy the dip
   else
     {
      // Get the price of the LAST buy order we opened (the lowest one)
      double lastOpenPrice = GetLowestBuyPrice();
      double currentAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

      // Calculate the drop distance (Convert points to price)
      double dropSize = GridStep * _Point;

      // IF price has dropped enough AND we haven't hit MaxOrders
      if(currentAsk <= (lastOpenPrice - dropSize) && openOrders < MaxOrders)
        {
         // Calculate new lot size (Previous Lot x Multiplier)
         double lastLotSize = GetLastLotSize();
         double newLotSize = NormalizeDouble(lastLotSize + LotMultiplier, 2);

         // Open the new "Martingale" trade
         trade.Buy(newLotSize, Symbol(), 0, 0, 0, "Grid Step " + IntegerToString(openOrders + 1));

         Print("Price dropped! Buying Step ", openOrders + 1, " with ", newLotSize, " lots.");
        }
     }
  }

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS (The "Engine" Room)                             |
//+------------------------------------------------------------------+

// Count how many buy trades are open
int CountBuyPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol == Symbol() && PositionGetInteger(POSITION_MAGIC) == magicNumber && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         count++;
        }
     }
   return count;
  }

// Find the lowest price we bought at
double GetLowestBuyPrice()
  {
   double minPrice = 999999;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol == Symbol() && PositionGetInteger(POSITION_MAGIC) == magicNumber && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         double price = PositionGetDouble(POSITION_PRICE_OPEN);
         if(price < minPrice)
            minPrice = price;
        }
     }
   return minPrice;
  }

// Find the lot size of the last trade to double it
double GetLastLotSize()
  {
// We assume the largest lot size is the last one (since we are doubling)
   double maxLot = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol == Symbol() && PositionGetInteger(POSITION_MAGIC) == magicNumber && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         double vol = PositionGetDouble(POSITION_VOLUME);
         if(vol > maxLot)
            maxLot = vol;
        }
     }
   if(maxLot == 0)
      return InitialLot;
   return maxLot;
  }

// Calculate total profit in USD
double GetTotalProfit()
  {
   double totalProfit = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol == Symbol() && PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
         totalProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
        }
     }
   return totalProfit;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePositions()
  {
   Trade = new CTrade; // A CTrade object to close positions.
   int total = PositionsTotal();
// Log in the terminal the total number of positions.
   Print(total);

// Start a loop to scan all the positions.
// The loop starts from the last, otherwise it could skip positions.
   for(int i = total - 1; i >= 0; i--)
     {
      // If the position cannot be selected, throw and log an error.
      if(PositionGetSymbol(i) == "")
        {
         Print("ERROR - Unable to select the position - ", GetLastError());
         break;
        }

      // Result variable - to check if the operation is successful or not.
      bool result = Trade.PositionClose(PositionGetInteger(POSITION_TICKET), Slippage);

      // If there was an error, log it.
      if(!result)
         Print("ERROR - Unable to close the position - ", PositionGetInteger(POSITION_TICKET), " - Error ", GetLastError());
     }
  }

// Close all trades immediately
void CloseAllTrades()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      if(symbol == Symbol() && PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
         trade.PositionClose(ticket);
        }
     }
   Print("Take Profit Hit! Closed all trades.");
  }
//+------------------------------------------------------------------+
