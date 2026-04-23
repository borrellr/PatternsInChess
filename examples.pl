%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  List of Examples
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  Example 1
%  Black King at a8
%  White King at a1
%  White Knight at e6
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
example(1) :-
  assertz(contents(white, king, square(1,1), pos1)),
  assertz(contents(white, knight, square(5,6), pos1)),
  assertz(contents(black, king, square(1,8), pos1)).