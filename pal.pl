:- module(pal, [
    pal/0,
    feature/1,
    description_pred/1,
    bg_fact/1
]).

/** <module> PAL – Perturbation-based Active Learning (SWI-Prolog)

A modernized, runnable reconstruction of the PAL learner:
- Interactive example generation via perturbation
- Positive/negative labeling
- Generalisation via LGG
- Simple reduction and bookkeeping

You can plug in your own domain by:
- Defining feature/1 predicates
- Defining description_pred/1 for example descriptions
- Adding background facts as bg_fact/1 or normal Prolog clauses
*/

:- dynamic feature/1.
:- dynamic description_pred/1.
:- dynamic current_exam/1.
:- dynamic stored_example/2.
:- dynamic list_of_levels/1.
:- dynamic bg_fact/1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Entry point
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pal :-
    initialise,
    load_example(Head, Feats, CFeats),
    gopos(Head, Feats, CFeats).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialisation and user interaction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

initialise :-
    retractall(stored_example(_, _)),
    retractall(current_exam(_)),
    retractall(list_of_levels(_)),
    % Example perturbation classes – adapt to your domain
    assertz(list_of_levels([pc1, pc2, pc3])),
    writeln('PAL learner initialised.').

display :-
    (   current_exam(E)
    ->  writeln('--- Current Example Description ---'),
        writeln(E),
        writeln('-----------------------------------')
    ;   writeln('No current example.')
    ).

pos_neg_stop(Type) :-
    writeln('Classify example: (p)ositive, (n)egative, (s)top'),
    read(User),
    ( User = p -> Type = positive
    ; User = n -> Type = negative
    ; User = s -> Type = stop
    ; writeln('Invalid input.'), pos_neg_stop(Type)
    ).

store_example(Type, Desc) :-
    assertz(stored_example(Type, Desc)).

stop(Head, Body) :-
    writeln('Final concept definition:'),
    pprint_defn(Head, Body),
    writeln('Learning stopped.').

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Pretty-printing of definitions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pprint_defn(Head, Body) :-
    writeq(Head),
    ( Body == [] ->
        writeln('.')
    ;   writeln(' :-'),
        pprint_body(Body)
    ).

pprint_body([]) :-
    writeln('    true.').
pprint_body([L]) :-
    write('    '), writeq(L), writeln('.').
pprint_body([L1,L2|Ls]) :-
    write('    '), writeq(L1), writeln(','),
    pprint_body([L2|Ls]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Positive example loop
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

gopos(GH, GFts, CFts) :-
    perturb(posit, GH, GFts, CFts,
            ExH, OldExDes, NewExDes, Fail, CFail),
    !,
    display,
    pos_neg_stop(Type),
    store_example(Type, NewExDes),
    !,
    (   Type = positive
    ->  generalise(GH, ExH, GFts, CFts, FinH, FinFts, NCFts),
        !,
        order_list_of_levels(NCFts),
        gopos(FinH, FinFts, NCFts)

    ;   Type = negative
    ->  restore_exam_descript(NewExDes, OldExDes),
        !,
        goneg(GH, GFts, CFts, Fail, CFail)

    ;   Type = stop
    ->  reduce_defn(GH, GFts, NH, NFts, CFts, _),
        stop(NH, NFts)
    ).

gopos(Head, Feats, CFeats) :-
    % No more perturbations – reduce and stop
    reduce_defn(Head, Feats, NHead, NFeats, CFeats, _),
    stop(NHead, NFeats).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Negative example loop
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

goneg(GH, GFts, CFts, Failed, CFailed) :-
    perturb(neg, GH, Failed, CFailed,
            ExH, OldExDes, NewExDes, _, _),
    !,
    display,
    pos_neg_stop(Type),
    store_example(Type, NewExDes),
    !,
    (   Type = positive
    ->  generalise(GH, ExH, GFts, CFts, FinH, FinFts, NCFts),
        !,
        order_list_of_levels(NCFts),
        gopos(FinH, FinFts, NCFts)

    ;   Type = negative
    ->  restore_exam_descript(NewExDes, OldExDes),
        !,
        goneg(GH, GFts, CFts, Failed, CFailed)

    ;   Type = stop
    ->  stop(GH, GFts)
    ).

goneg(GH, GF, CF, _, _) :-
    % Last perturbation level – go back to positive loop
    gopos(GH, GF, CF).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Load example and feature extraction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear_board :-
    retractall(current_exam(_)).

which_example(Head) :-
    writeln('Enter initial example head (as Prolog term, e.g. concept(a,b)):'),
    read(Head),
    assertz(current_exam([Head])).

load_example(Head, Feats, CFeats) :-
    clear_board,
    which_example(Head),
    !,
    display,
    extract_features(Feats, CFeats).

extract_features(Fts, CFts) :-
    (   setof(X, feature(X), ListFeats)
    ->  all_features(ListFeats, Fts, CFts)
    ;   Fts = [], CFts = []
    ).

all_features([], [], []).
all_features([Feat|Rest], Feats, CFeats) :-
    copy_term(Feat, CFeat),
    setof(Feat/CFeat, mebg(Feat, CFeat), All),
    divide_2(All, Feats1, CFeats1),
    numbervars(CFeats1, 0, _),
    all_features(Rest, Feats2, CFeats2),
    append(Feats1, Feats2, Feats),
    append(CFeats1, CFeats2, CFeats).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Modified EBG (mebg)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mebg((A,B), Subs) :- !,
    mebg(A, Subs),
    mebg(B, Subs).
mebg((A;B), Subs) :- !,
    (   mebg(A, Subs)
    ;   mebg(B, Subs)
    ).
mebg(true, _) :- !.

mebg(A, _) :-
    \+ predicate_property(A, dynamic),
    !,
    call(A).

mebg(Pred, Subs) :-
    description_pred(P/A),
    functor(Pred, P, A),
    !,
    current_exam(L),
    member(Pred/Args, L),
    new_subst(Pred, Args, Subs).

mebg(A, Subs) :-
    clause(A, Tail),
    mebg(Tail, Subs).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Generalisation (LGG)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

generalise(GH, ExH, GFts, CFts, FH, FFts, NCFts) :-
    extract_features(ExFts, CExFts),
    heads_lgg(GH, ExH, NGH, Subst),
    all_feats_lgg(GFts, CFts, ExFts, CExFts, Subst, NGFts, NCFts),
    reduce_defn(NGH, NGFts, FH, FFts, NCFts, _),
    pprint_defn(FH, FFts).

heads_lgg(H1, H2, LGG, Subst) :-
    H1 =.. [P|A1],
    H2 =.. [P|A2],
    maplist(lgg_term, A1, A2, GA, SubstList),
    LGG =.. [P|GA],
    flatten(SubstList, Subst).

lgg_term(X, X, X, []) :- !.
lgg_term(X, Y, V, [X/Y/V]) :-
    X \= Y,
    V = v(X,Y).

all_feats_lgg(F1, _CF1, F2, _CF2, _Subst, LGG, Labels) :-
    same_length(F1, F2),
    maplist(lgg_literal, F1, F2, LGG, Labels).

lgg_literal(L1, L2, LGG, lbl) :-
    L1 =.. [P|A1],
    L2 =.. [P|A2],
    maplist(lgg_term_simple, A1, A2, GA),
    LGG =.. [P|GA].

lgg_term_simple(X, X, X) :- !.
lgg_term_simple(_, _, v).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Perturbation system
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

perturb(Type, H, Fts, CFts, ExH, OldExDes, NewExDes, Fail, CFail) :-
    list_of_levels([PC|_]),
    change(Type, PC, H, Fts, CFts, ExH, OldExDes, NewExDes, Fail, CFail).
perturb(Type, H, Fts, CFts, NH, OldExDes, NewExDes, F, CF) :-
    change_levels,
    !,
    perturb(Type, H, Fts, CFts, NH, OldExDes, NewExDes, F, CF).

list_of_levels(Levels) :-
    clause(list_of_levels(Levels), _).

change_levels :-
    retract(list_of_levels([_|Rest])),
    (   Rest = []
    ->  fail
    ;   assertz(list_of_levels(Rest))
    ).

change(Fl, PC, H, Fts, CFts, NH, OldP, NewP, Fail, CFail) :-
    change_aux(PC, H, Fts, OldP, Args, CArgs),
    change_args(Args, PC, NArgs, NewP),
    check_if_legal,
    replace_all_args(NArgs, CArgs, CFts, Fts, NFts),
    check_defn(Fl, Fts, NFts, CFts, Fail, CFail),
    check_fails(Fl, Fail, CFail, Args, NArgs, PC),
    !,
    produce_head(Args, NArgs, H, NH, _).

change_aux(_PC, H, _Fts, OldP, Args, Args) :-
    (   current_exam(OldP)
    ->  true
    ;   OldP = []
    ),
    H =.. [_|Args].

change_args(Args, _PC, NewArgs, NewP) :-
    maplist(randomize_arg, Args, NewArgs),
    NewP = NewArgs.

randomize_arg(Old, New) :-
    ( atomic(Old) ->
        random_between(1, 9, R),
        atom_concat(Old, R, New)
    ; New = Old
    ).

check_if_legal :- true.

replace_all_args(NewArgs, _CArgs, _CFts, Fts, NFts) :-
    maplist(replace_literal_args(NewArgs), Fts, NFts).

replace_literal_args(NewArgs, Lit, NewLit) :-
    Lit =.. [P|_],
    NewLit =.. [P|NewArgs].

check_defn(_Fl, _Fts, NewFts, _CFts, Fail, CFail) :-
    findall(L, (member(L, NewFts), \+ safe_call(L)), Fail),
    maplist(dummy_label, Fail, CFail).

safe_call(L) :-
    (   bg_fact(L)
    ;   call(L)
    ), !.

dummy_label(_, lbl).

check_fails(_Fl, Fail, _CFail, _Args, _NArgs, _PC) :-
    Fail \= [].

produce_head(Args, _NArgs, H, NH, _) :-
    H =.. [Pred|_],
    NH =.. [Pred|Args].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Reduction (simple placeholder)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

reduce_defn(H, Fts, H, Fts, CFts, CFts).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Utilities
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

divide_2([], [], []).
divide_2([A/B|Rest], [A|As], [B|Bs]) :-
    divide_2(Rest, As, Bs).

new_subst(Pred, Args, [Pred-Args]).

order_list_of_levels(Levels) :-
    sort(Levels, Levels).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Example hooks (to be customised)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Example: declare which predicates are features
% :- assertz(feature(bg_fact(_))).

% Example: declare which predicates describe example positions
% :- assertz(description_pred(bg_fact/1)).

% Example background fact
% bg_fact(example(a,b)).