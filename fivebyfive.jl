using Underscores, Test
using DataStructures: DefaultDict
using SplitApplyCombine: group

A_TO_Z = ['a':'z';]

begin
    # could be cached
    char_to_bit(c::Char) = 1 << (Int8(c) - Int8('a'))
    # could we make this officially look like a set?
    struct LetterSet
        bits::Int
    end
    LetterSet(chars) = LetterSet(sum(char_to_bit.(collect(chars))))

    # Set-like operations
    Base.intersect(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits & ls2.bits)
    Base.union(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits | ls2.bits)
    Base.setdiff(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits & ~ls2.bits)
    Base.length(ls::LetterSet) = count_ones(ls.bits)
    Base.empty(ls::LetterSet) = ls.bits == 0
    

    # Sorting
    Base.isless(ls1::LetterSet, ls2::LetterSet) = ls1.bits < ls2.bits

    # Visualising
    A_TO_Z_BITS = char_to_bit.(collect(A_TO_Z))
    to_letters(ls::LetterSet) = A_TO_Z[(A_TO_Z_BITS .& ls.bits) .> 0]
    Base.show(io::IO, ls::LetterSet) = print(io, "LetterSet($(ls.bits); \"$(String(to_letters(ls)))\")")

    if false # Inline tests
        @testset "LetterSet" begin 
            LS = LetterSet
            @test LS("abc") == LS(7)
            @test union(LS("abc"), LS("dce")) == LS("abcde")
            @test intersect(LS("abc"), LS("dce")) == LS("c")
            @test setdiff(LS("abc"), LS("dce")) == LS("ab")
            @test setdiff(LS("abc"), LS("cba")) == LS("")
            @test empty(LS(""))
            @test length("a") == 1
            @test length("five") == 4
            @test to_letters(LetterSet("cab")) == collect("abc")
        end
    end
end

LS = LetterSet

A_TO_Z_LETTER_SET = LS(A_TO_Z)

# raw_words = readlines("/usr/share/dict/words")
raw_words = readlines(download("https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt"))
words = @_ raw_words |> filter(length(_) == 5, __) .|> lowercase |> unique

function find_spents(word_list)
    sword_lookup = group(LetterSet, word_list)
    swords = @_ LetterSet.(word_list) |> filter(length(_) == 5, __) |> sort


    spair_lookup = DefaultDict{LS, Vector{Pair{LS, LS}}}([])
    for (i, test_sword) in enumerate(swords)
        for sword in swords[i+1:end]
            if empty(intersect(test_sword, sword))
                push!(spair_lookup[union(test_sword, sword)], (test_sword => sword))
            end
        end
    end

    spairs = sort(collect(keys(spair_lookup)))

    striple_lookup = DefaultDict{LS, Vector{Pair{LS, LS}}}(Vector{Pair{LS, LS}})
    s_i = 1
    for test_spair in spairs
        global s_i
        while s_i <= length(swords) && swords[s_i] < test_spair; s_i += 1; end
        for sword in swords[s_i:end]
            if empty(intersect(test_spair, sword))
                push!(striple_lookup[union(test_spair, sword)], (test_spair => sword))
            end
        end
    end
    striples = sort(collect(keys(striple_lookup)))

    squad_lookup = DefaultDict{LS, Vector{Pair{LS, LS}}}(Vector{Pair{LS, LS}})
    s_i = 1
    for test_striple in striples
        global s_i
        while s_i <= length(swords) && swords[s_i] < test_striple; s_i += 1; end
        for sword in swords[s_i:end]
            if empty(intersect(test_striple, sword))
                push!(squad_lookup[union(test_striple, sword)], (test_striple => sword))
            end
        end
    end
    squads = sort(collect(keys(squad_lookup)))

    spent_lookup = DefaultDict{LS, Vector{Pair{LS, LS}}}(Vector{Pair{LS, LS}})
    s_i = 1
    for test_squad in squads
        global s_i
        while s_i <= length(swords) && swords[s_i] < test_squad; s_i += 1; end
        for sword in swords[s_i:end]
            if empty(intersect(test_squad, sword))
                push!(spent_lookup[union(test_squad, sword)], (test_squad => sword))
            end
        end
    end

    # Should overcount until we fix sorting (probably by 2x)
    spents = sort(collect(keys(spent_lookup)))

    (
        swords=swords,
        sword_lookup=sword_lookup,
        spairs=spairs,
        spair_lookup=spair_lookup,
        striples=striples,
        striple_lookup=striple_lookup,
        squads=squads,
        squad_lookup=squad_lookup,
        spents=spents,
        spent_lookup=spent_lookup
    )
end