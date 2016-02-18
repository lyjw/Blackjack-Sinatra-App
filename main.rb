require 'rubygems'
require 'sinatra'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'hello there'

helpers do
  INITIAL_CASH = 500
  BLACKJACK = 21
  DEALER_MIN_HAND = 17
  SET_OF_CARDS = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king', 'queen']
  SUITS = ['spades', 'hearts', 'clubs', 'diamonds']

  def to_image(card)
    "/images/cards/" + card[0] + "_" + card[1] + ".jpg"
  end

  def deal_initial_cards
    2.times do
     hit(session[:player_cards])
     hit(session[:dealer_cards])
   end
  end

  def hit(hand)
    hand << session[:deck].pop
  end

  def calculate_total(hand)
    total = 0

    hand.each do |card|
      face = card[1]
      if face == 'A'
        total += 11
      elsif face.to_i == 0
        total += 10
      else
        total += face.to_i
      end
    end

    # correct for Aces
    hand.map { |card| card[0] }.count('A').times do
      total -= 10 if total > 21
    end

    total
  end

  def winner!(msg)
    @player_win = true
    @show_hit_or_stay_buttons = false
    session[:player_pool] += session[:bet]
    @winner = "<strong>#{session[:player_name]} wins!</strong> #{msg} #{session[:player_name]} won $#{session[:bet]} and now has $#{session[:player_pool]}.
    <a href='/place_bet'>Another Game?</a>"
  end

  def loser!(msg)
    @dealer_win = true
    @show_hit_or_stay_buttons = false
    session[:player_pool] -= session[:bet]
    @loser = "<strong>#{session[:player_name]} loses.</strong> #{msg} #{session[:player_name]} lost $#{session[:bet]} and now has $#{session[:player_pool]}.
    <a href='/place_bet'>Another Game?</a>"
  end

  def tie!(msg)
    @show_hit_or_stay_buttons = false
    @tie = "<strong>It's a tie!</strong> #{msg} <a href='/place_bet'>Another Game?</a>"
  end
end

before do
  session[:turn] = nil
  @show_hit_or_stay_buttons = true
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/set_name'
  end
end

get '/set_name' do
  session[:player_name] = nil
  session[:player_pool] = INITIAL_CASH
  session[:track_bets] = []

  erb :set_name
end

post '/set_name' do
  if params[:player_name].empty?
    session[:player_name] = nil
    @error = "<b>A name is required</b>"
    halt erb :set_name
  elsif params[:player_name] =~ /\d+/
    session[:player_name] = nil
    @error = "<b>That is not a valid name.</b> Please only enter alphabetical characters"
    halt erb :set_name
  end

  session[:player_name] = params[:player_name]

  redirect '/place_bet'
end

get '/place_bet' do
  session[:bet] = nil
  erb :place_bet
end

post '/place_bet' do
  if params[:bet] =~ /\D+/
    @error = "<b>That is not a valid amount.</b> Please enter a number."
    halt erb :place_bet
  elsif params[:bet].empty? || params[:bet].to_i == 0
    @error = "<b>Please place a bet.</b>"
    halt erb :place_bet
  elsif params[:bet].to_i > session[:player_pool]
    @error = "You do not have enough to bet $#{params[:bet]}."
    halt erb :place_bet
  end

  session[:bet] = params[:bet].to_i
  session[:track_bets] << params[:bet]

  redirect '/game'
end

get '/game' do
  session[:turn] = session[:player_name]

  session[:deck] = SUITS.product(SET_OF_CARDS).shuffle!
  session[:player_cards] = []
  session[:dealer_cards] = []

  deal_initial_cards

  erb :game
end

post '/game/player/hit' do
  @old_player_pool = session[:player_pool]
  hit(session[:player_cards])

  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK
    winner!("#{session[:player_name]} hit Blackjack!")
  elsif player_total > BLACKJACK
    loser!("#{session[:player_name]} busted at #{player_total}.")
  end

  erb :game, layout: false
end

post '/game/player/stay' do
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = "dealer"
  @show_hit_or_stay_buttons = false
  @old_player_pool = session[:player_pool]

  dealer_total = calculate_total(session[:dealer_cards])

  if dealer_total == BLACKJACK
    loser!("Dealer hit Blackjack!")
  elsif dealer_total > BLACKJACK
    winner!("Dealer busted at #{dealer_total}.")
  elsif dealer_total < DEALER_MIN_HAND
    @show_reveal_card_button = true
  elsif dealer_total > DEALER_MIN_HAND || dealer_total == DEALER_MIN_HAND
    redirect '/game/compare'
  end

  erb :game, layout: false
end

post '/game/dealer/hit' do
  hit(session[:dealer_cards])
  redirect '/game/dealer'
end

get '/game/compare' do
  @show_reveal_card_button = false

  player_name = session[:player_name]
  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])
  @old_player_pool = session[:player_pool]

  if player_total > dealer_total
    winner!("#{player_name} stayed at #{player_total} and Dealer stayed at #{dealer_total}.")
  elsif dealer_total > player_total
    loser!("#{player_name} stayed at #{player_total} and Dealer stayed at #{dealer_total}.")
  else
    tie!("Both #{player_name} and Dealer stayed at #{player_total}.")
  end

  erb :game
end

get '/game_over' do
  @sorted_bets = session[:track_bets].map! { |bet| bet }.sort
  @rounds_played = @sorted_bets.size
  @smallest_bet = @sorted_bets.first
  @largest_bet = @sorted_bets.last
  @winnings = session[:player_pool] - INITIAL_CASH

  erb :game_over
end
