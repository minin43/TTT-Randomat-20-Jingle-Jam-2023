# _A Round Of Yogscast Poker_ event for the _Randomat 2.0_ Events Pack for Jingle Jam 2023
A supplementary event created by Logan Christianson for the [Randomat 2.0 Events Pack for Jingle Jam 2023](https://github.com/Malivil/TTT-Randomat-20-Jingle-Jam-2023), a pack of [Randomat 2.0](https://github.com/Malivil/TTT-Randomat-20) events created in support of [Jingle Jam 2023](https://www.jinglejam.co.uk/).

# Events

## A Round Of Yogscast Poker
Only if the 9 of Diamonds touch!\
A round of 5-Card Draw Poker (no Texas Hold 'Em, for my sake), bet with your health. Up to 7 may play. Any pair, three, or four of a kind containing the 9 of Diamonds instantly wins.
\
\
**ConVars**
\
_ttt_randomat_poker_ - Default: 1 - Whether this event is enabled.\
_ttt_randomat_poker_min_players_ - Default: 2 - The minimum number of players required for this event to start.\
_ttt_randomat_poker_weight_ - Default: -1 - The weight this event should use during the randomized event selection process.\
_randomat_poker_manual_round_state_times_ - Default: 0 - Enables use of the various 'RoundState*' ConVars.\
_randomat_poker_round_state_start_ - Default: 5 - Manually overrides how long clients have to repond to the initial game start.\
_randomat_poker_round_state_betting_ - Default: 30 - Manually overrides how long the 'betting' phase of the round lasts.\
_randomat_poker_round_state_discarding_ - Default: 30 - Manually overrides how long the 'discarding' phase of the round lasts.\
_randomat_poker_round_state_message_ - Default: 5 - Manually overrides how long the round state messages should appear for.\
_randomat_poker_round_state_end_ - Default: 5 - Manually overrides how long the game outcome message lasts for (as well as how long to wait before starting a new round if continuous play is enabled).\
_randomat_poker_enable_yogsification_ - Default: 1 - Enables the Yogscast sfx.\
_randomat_poker_enable_audio_cues_ - Default: 1 - Enables the round state audio cues.\
_randomat_poker_enable_continuous_play_ - Default: 0 - Enables continuous play, event repeats until TTT game ends.\
_randomat_poker_enable_smaller_bets_ - Default: 0 - Enables smaller bet increments (default: 25-50-75-100, alt: 10-20-30-...-100).\
_randomat_poker_enable_nine_diamonds_ - Default: 1 - Enables the 9 of Diamonds win condition gag.

## A Suspicious Round Of Yogscast Poker
The women are colluding!\
A variant game of Yogscast Poker, but the women are colluding. Uses the non-variant mode's ConVars.
\
\
**ConVars**
\
_ttt_randomat_poker_colluding_ - Default: 1 - Whether this event is enabled.\
_ttt_randomat_poker_colluding_min_players_ - Default: 3 - The minimum number of players required for this event to start.\
_ttt_randomat_poker_colluding_weight_ - Default: -1 - The weight this event should use during the randomized event selection process.\
_randomat_poker_colluding_enable_random_collusions_ - Default: 1 - Enables whether your colluding partner should be randomized or ordered.\
_randomat_poker_colluding_anonymized_collusions_ - Default: 1 - Enables whether the colluding partner's name should be hidden.\
_All randomat\_poker\_* ConVars_

# Special Thanks
- Malivil and Nick for their help debugging code and playtesting the event with me
- The [vector-playing-cards](https://code.google.com/archive/p/vector-playing-cards/downloads) project on Google Code for the playing card images
- [n Beats](https://www.youtube.com/watch?v=1jDlRDV3__M) for the card shuffling sound effect
- [Gfx Sounds](https://gfxsounds.com/free-sound-effects/) for the [poker chips sound effect](https://www.youtube.com/watch?v=rYhKm5qsfZE)