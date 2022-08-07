# ParkerSlayer

Finding 5 5-letter words with 25 letters in under 5 microparkers.

## Description 

The notorious Matt Parker recently posted a video ["Can you find: five five-letter words with twenty-five unique letters?"](https://www.youtube.com/watch?v=_-AfhLQfb6w) based on his "[A problem squared podcast](https://aproblemsquared.libsyn.com/). Matt applied the age-old "brute force" technique and was able solve the problem in only one "parker" (32 days to the uninitiated).

Unsure if I'd live another parker, I sat down, determined to save my computer minion from such an arduous task. I was not alone. Even before I began, the venerable Benjamen Passen had already slain the beast in a mere 326 microparkers (20 minutes to humans) with something called "Graph Theory". His wizardry is available for inspection [here](https://gitlab.com/bpaassen/five_clique).

But I don't have 326 milliparkers to spare, so I set aside a Saturday in the hopes of saving myself 20 minutes. Unfortunately, it's been eons since my apprenticeship and my "Theory" skills are rusty, so I'd have to start from scratch.

Fueled by coffee, and aided by the powerful god known as Julia, I fought of monster after monster, and bravely cut my way through the dark forest of typos. And through all my struggles I was triumphant! I did the impossible! I was able to identify all 831 magic phrases in under 5 micro parkers (15 human secunds)!

Though I believe this feat to be surmountable, I must pass on the sword to another brave adventurer. May the stacktraces always be on your side.

## Installing & running

 * [Download & install Julia](https://julialang.org/downloads/)
   * You may need to [add Julia to your PATH](https://julialang.org/downloads/platform/) to run from the command line
   * I installed 1.8.0rc3 for M1 mac, since earlier builds do not run on M1 chips, but should run fine on 1.7.3
 * `git clone git@github.com:kmacdough/Parker5Slayer.git`
 * `cd Parker5Slayer`
 * `julia fivebyfive.jl`

## Understanding the code

This code might be a little hard to follow, especially for those new to Julia. It makes use of Julia's custom type system, allowing me to store Letter Sets as integers. This has 2 main benefits:

 * super fast set operations using basic bitwise operations e.g.
   * "abc" ~ 7                  (0b0000000000000111)
   * "cde" ~ 28                 (0b0000000000011100)
   * "abc" == "cab"
   * "abc" | "cde" == "abcde"   (0b0000000000011111)
   * "abc" & "cde" == "c"       (0b0000000000000100)
 * Natural ordering for anagrams, treating bits as an Integer.
   * This is crucial for avoiding duplicates, cutting the search space ENORMOUSLY
   * For the particular choices I made, it's ordered by the "largest" letter
     * NOTE order is thrown out in set form, I write them in aphabetic order here for conveience)
   * e.g.
     * "abc" < "cde"
     * "bc" < "az"