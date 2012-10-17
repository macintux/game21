%%% @author John Daily <spam@epep.us>
%%% @copyright (C) 2012, John Daily
%%% @doc
%%%   Solving simple game problems from the classic MIT 6.001 class.
%%%   Simplified blackjack with limited rules, strictly numeric cards.
%%%
%%% @reference See <a href="http://mitpress.mit.edu/sicp/psets/ps2tw1/readme.html">The Game of Twenty-one</a>.
%%%
%%% Example, invoked via `erl':
%%% ```
%%% > game21:test_strategy(fun game21:louis/2, game21:stop_at(16), 1000).
%%% 343'''
%%%
%%% Note the lazy evaluation for the first argument: `test_strategy'
%%% expects two anonymous functions, so we pass `louis' as a function
%%% reference, but `stop_at' is invoked to generate an anonymous
%%% function.
%%%
%%% @end

-module(game21).

%% Functions to initiate game play
-export([start/2, test_strategy/3]).

%% Strategy functions
-export([hit1/2, louis/2]).

%% Functions that generate strategy functions
-export([stop_at/1, both/2, watch_player/1]).

-type card() :: non_neg_integer().
-type action() :: 'draw' | 'done' | 'quit' | 'retry'.
-type hand() :: non_neg_integer().
-type actionresult() :: { ok, card() } | action().
-type endresult() :: 'user_quit' | 'user_busted' | 'house_busted' | 'house_won' | 'user_won'.

%% A strategy function takes a hand, a face up card for the opponent,
%% and decides what to do by returning an action.
-type strategyfun() :: fun((hand(), card()) -> action()).



%% For each user (player and the house): the current hand tally, the
%% card facing up, and the strategy function to decide whether to
%% draw or hold
-record(userstate,
        { tally = 0 :: hand(),
          upcard :: card(),
          strategy :: strategyfun()
        }).
-type userstate() :: #userstate{}.

%% @doc If the strategy passes the draw argument, retrieve a card,
%% else return the alternative action() that prevents a draw.
-spec next_card_or_not(action()) -> actionresult().
next_card_or_not(draw) ->
    { ok, generate_card() };
next_card_or_not(X) ->
    X.

%% @doc Trigger a game of 21.
-spec start(strategyfun(), strategyfun()) -> endresult().
start(HouseStrategy, PlayerStrategy) ->
    HouseUp = generate_card(),
    PlayerUp = generate_card(),
    HouseState = #userstate{ tally = HouseUp, upcard = HouseUp, strategy = HouseStrategy },
    PlayerState = #userstate{ tally = PlayerUp, upcard = PlayerUp, strategy = PlayerStrategy },
    run_player_strategy(HouseState, PlayerState,
                next_card_or_not(PlayerStrategy(PlayerUp, HouseUp))).

%% @doc Trigger TryCount games of 21. Take two strategies, the first
%% for the player, the second for the house, and run them TryCount
%% times to see how often the player wins.
-spec test_strategy(strategyfun(), strategyfun(), non_neg_integer()) -> non_neg_integer().
test_strategy(Player, House, TryCount) ->
    test_strategy_tally(Player, House, TryCount, 0).


%% Take the results from PlayerStrategy and run HouseStrategy if the
%% user doesn't bust. Will recurse until the player is done.
%%
%% The strategy functions can return one of:
%%            draw    Draw a card
%%            done    User is done drawing
%%            quit    User quit
%%           retry    User input was not recognized
%%
%% This function will return one of:
%%       user_quit
%%     user_busted
%%    house_busted
%%       house_won
%%        user_won

-spec run_player_strategy(HouseState::userstate(), PlayerState::userstate(), actionresult()) -> endresult().

run_player_strategy(_HouseState, #userstate{ tally = PlayerTally }, { ok, PlayerCard })
  when PlayerCard + PlayerTally > 21 ->
    user_busted;
run_player_strategy(#userstate{ upcard = HouseUp } = HouseState,
                    #userstate{ tally = PlayerTally, upcard = PlayerUp,
                                strategy = PlayerStrategy }, { ok, PlayerCard }) ->
    run_player_strategy(HouseState,
                        #userstate { tally = PlayerCard + PlayerTally,
                                     upcard = PlayerUp, strategy = PlayerStrategy },
                        next_card_or_not(PlayerStrategy(PlayerCard + PlayerTally, HouseUp)));
run_player_strategy(#userstate { upcard = HouseUp } = HouseState,
                    #userstate{ tally = PlayerTally, strategy = PlayerStrategy } = PlayerState,
                    retry) ->
    run_player_strategy(HouseState, PlayerState, PlayerStrategy(PlayerTally, HouseUp));
run_player_strategy(#userstate{ tally = HouseTally, strategy = HouseStrategy } = HouseState,
                    #userstate{ upcard = PlayerUp } = PlayerState,
                    done) ->
    run_house_strategy(HouseState, PlayerState,
                       next_card_or_not(HouseStrategy(HouseTally, PlayerUp)));
run_player_strategy(_, _, quit) ->
    user_quit.

%% Invoked after run_player_strategy to perform the house draw activity
-spec run_house_strategy(HouseState::userstate(), PlayerState::userstate(), actionresult()) -> endresult().
run_house_strategy(#userstate{ tally = HouseTally }, _PlayerState,
                   { ok, HouseCard }) when HouseCard + HouseTally > 21 ->
    house_busted;
run_house_strategy(#userstate{ tally = HouseTally, upcard = HouseUp,
                               strategy = HouseStrategy },
                   #userstate{ upcard = PlayerUp } = PlayerState,
                   { ok, HouseCard }) ->
    run_house_strategy(#userstate { tally = HouseCard + HouseTally,
                                    upcard = HouseUp, strategy = HouseStrategy },
                       PlayerState,
                       next_card_or_not(HouseStrategy(HouseCard + HouseTally, PlayerUp)));
run_house_strategy(#userstate{ tally = HouseTally, strategy = HouseStrategy } = HouseState,
                   #userstate { upcard = PlayerUp } = PlayerState,
                   retry) ->
    run_house_strategy(HouseState, PlayerState,
                       next_card_or_not(HouseStrategy(HouseTally, PlayerUp)));
run_house_strategy(#userstate{ tally = HouseTally },
                   #userstate{ tally = PlayerTally },
                   done) when HouseTally >= PlayerTally ->
    house_won;
run_house_strategy(_HouseState,
                   _PlayerState,
                   done) ->
    user_won;
run_house_strategy(_, _, quit) ->
    user_quit.


%% @doc Louis' 21 strategy: draw if the current hand is &lt; 12, hold if
%% &gt; 16, and otherwise decide what to do based on the house's up card.
-spec louis(hand(), card()) -> action().
louis(Tally, _OpponentUp) when Tally < 12 ->
    draw;
louis(Tally, _OpponentUp) when Tally > 16 ->
    done;
louis(Tally, OpponentUp) when Tally =:= 12, OpponentUp < 4 ->
    draw;
louis(Tally, _OpponentUp) when Tally =:= 12 ->
    done;
louis(Tally, OpponentUp) when Tally =:= 16, OpponentUp =:= 10 ->
    done;
louis(Tally, _OpponentUp) when Tally =:= 16 ->
    draw;
louis(_Tally, OpponentUp) when OpponentUp > 6 ->
    draw;
louis(_, _) ->
    done.

%% @doc A strategy function generator that takes 2 strategies and
%% returns a new one that will only draw if both say to draw.
-spec both(strategyfun(), strategyfun()) -> strategyfun().
both(S1, S2) ->
    fun(Tally, OpponentUp) ->
            case S1(Tally, OpponentUp) of
                draw ->
                    S2(Tally, OpponentUp);
                _ ->
                    done
            end
    end.



%% @doc Take a strategy and return a wrapper function that will
%% display the inputs and outputs.
-spec watch_player(strategyfun()) -> strategyfun().
watch_player(F) ->
    fun(Tally, OpponentUp) ->
            io:format("Current hand: ~B, Opponent card: ~B~n",
                      [Tally, OpponentUp]),
            Choice = F(Tally, OpponentUp),
            io:format("Strategy decided to ~p~n", [ Choice ]),
            Choice
    end.

%% Utility function for test_strategy
-spec test_strategy_tally(strategyfun(), strategyfun(), non_neg_integer(), non_neg_integer()) -> non_neg_integer().
test_strategy_tally(_Player, _House, 0, PlayerWon) ->
    PlayerWon;
test_strategy_tally(Player, House, CountDown, PlayerWon) ->
    test_strategy_tally(Player, House, CountDown - 1,
                        PlayerWon + test_if_player_won(start(House, Player))).

-spec test_if_player_won(endresult()) -> non_neg_integer().
test_if_player_won(user_won) ->
    1;
test_if_player_won(house_busted) ->
    1;
test_if_player_won(_) ->
    0.


%% @doc Simple strategy function that asks the user to decide.
-spec hit1(hand(), card()) -> action().
hit1(Tally, OpponentUp) ->
    io:format("Opponent facing up: ~B~n", [ OpponentUp ]),
    io:format("Your current total: ~B~n", [ Tally ]),
    prompt_user(),
    handle_user_input(file:read_line(standard_io)).

%% @doc Strategy generator; the strategy will stop when the hand tally
%% reaches Stop
-spec stop_at(non_neg_integer()) -> strategyfun().
stop_at(Stop) ->
    fun(Tally, _OpponentUp) when Tally >= Stop ->
            done;

       (_Tally, _OpponentUp) ->
            draw
       end.

%%
%% Drop any end of line marker by splitting on them and returning the
%% first component
-spec chomp(string()) -> string().
chomp(String) ->
    [Line | _Leftover] = string:tokens(String, "\r\n"),
    Line.

-spec prompt_user() -> 'ok'.
prompt_user()->
    io:format("Take a card? ").

-spec handle_user_input({ ok, string() } | eof | { error, string() }) -> actionresult().
handle_user_input({ok, [$Y|_Tail]}) ->
    { ok, generate_card() };
handle_user_input({ok, [$y|_Tail]}) ->
    { ok, generate_card() };
handle_user_input({ok, [$N|_Tail]}) ->
    done;
handle_user_input({ok, [$n|_Tail]}) ->
    done;
handle_user_input({ok, [$Q|_Tail]}) ->
    quit;
handle_user_input({ok, [$q|_Tail]}) ->
    quit;
handle_user_input({ok, Other}) ->
    io:format("Sorry, didn't understand ~p~n", [ chomp(Other) ]),
    retry;
handle_user_input({error, What}) ->
    io:format("Error: ~p~n", [ What ]),
    retry;
handle_user_input(eof) ->
    io:format("Goodbye.~n"),
    quit.

%% Per the MIT assignments, just generates a value between 1 and 10,
%% doesn't try to simulate a real deck of cards
-spec generate_card() -> card().
generate_card() ->
    random:uniform(10).
