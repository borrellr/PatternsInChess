%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Modern SWI‑Prolog Chess Background for PAL
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:- dynamic contents/4.
:- dynamic current_state/1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Basic domain definitions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

side(white).
side(black).

piece(pawn).
piece(knight).
piece(bishop).
piece(rook).
piece(queen).
piece(king).

square(X,Y) :- between(1,8,X), between(1,8,Y).

other_side(white,black).
other_side(black,white).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Legal move: piece can move and does not expose own king
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

legal_move(Side,Piece,Place,NewPlace,Pos1) :-
    contents(Side,Piece,Place,Pos1),
    piece_move(Side,Piece,Place,NewPlace,Pos1),
    do_move(Side,Piece,Place,NewPlace,Pos1,Pos2),
    \+ in_check(Side,_,_,_,Pos2).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% In check: opponent has a plausible move to king
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

in_check(Side,KPlace,OPiece,OPlace,Pos) :-
    contents(Side,king,KPlace,Pos),
    other_side(Side,OSide),
    contents(OSide,OPiece,OPlace,Pos),
    piece_move(OSide,OPiece,OPlace,KPlace,Pos).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Checkmate: king in check and cannot move
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

check_mate(Side,Place,Pos) :-
    contents(Side,king,Place,Pos),
    in_check(Side,Place,_,_,Pos),
    \+ legal_move(Side,king,Place,_,Pos).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Stalemate: piece cannot move and opponent king not in check
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

stale(Side,Piece,Place,Pos) :-
    contents(Side,Piece,Place,Pos),
    \+ legal_move(Side,Piece,Place,_,Pos),
    other_side(Side,OSide),
    \+ in_check(OSide,_,_,_,Pos).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Move simulation (transactional)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

do_move(Side,Piece,Place,NewPlace,Pos1,Pos2) :-
    save_state(State),
    create_new_state(Pos1,State,Pos2,NState),
    retract_if_there(contents(_,_,NewPlace,Pos2)),
    retract(contents(Side,Piece,Place,Pos2)),
    asserta(contents(Side,Piece,NewPlace,Pos2)),
    !,
    restore_if_redo(State).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% State management
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

save_state(State) :-
    findall(contents(S,P,Pl,Pos), contents(S,P,Pl,Pos), State).

restore_state(State) :-
    retractall(contents(_,_,_,_)),
    maplist(assertz, State).

restore_if_redo(_).
restore_if_redo(State) :-
    restore_state(State),
    !,
    fail.

create_new_state(Pos,State,NPos,NState) :-
    new_pos(NPos),
    replace_pos(Pos,NPos,State,NState),
    maplist(assertz, NState).

new_pos(N) :- gensym(pos, N).

replace_pos(_,_,[],[]).
replace_pos(Old,New,[contents(S,P,Pl,Old)|T],[contents(S,P,Pl,New)|R]) :-
    replace_pos(Old,New,T,R).
replace_pos(Old,New,[H|T],[H|R]) :-
    replace_pos(Old,New,T,R).

retract_if_there(Goal) :-
    (   Goal -> retract(Goal) ; true ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Sliding pieces (queen, bishop, rook)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sliding_piece(Piece,Place,Pos) :-
    contents(_,Piece,Place,Pos),
    member(Piece,[queen,bishop,rook]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Feature declarations for PAL
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

feature(contents(_,_,square(_,_),_)).
feature(legal_move(_,_,square(_,_),square(_,_),_)).
feature(in_check(_,square(_,_),_,square(_,_),_)).
feature(check_mate(_,square(_,_),_)).
feature(stale(_,_,square(_,_),_)).
feature(sliding_piece(_,square(_,_),_)).

description_pred(contents/4).