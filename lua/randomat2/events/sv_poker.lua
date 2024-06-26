--// Logan Christianson

util.AddNetworkString("StartPokerRandomat")
util.AddNetworkString("StartPokerRandomatCallback")
util.AddNetworkString("BeginPokerRandomat")
util.AddNetworkString("NotifyBlinds")
util.AddNetworkString("DealCards")
util.AddNetworkString("StartBetting")
util.AddNetworkString("MakeBet")
util.AddNetworkString("PlayerFolded")
util.AddNetworkString("PlayerChecked")
util.AddNetworkString("PlayerCalled")
util.AddNetworkString("PlayerRaised")
util.AddNetworkString("StartDiscard")
util.AddNetworkString("PlayersFinishedBetting")
util.AddNetworkString("MakeDiscard")
util.AddNetworkString("DeclareNoWinner")
util.AddNetworkString("DeclareWinner")
util.AddNetworkString("ClosePokerWindow")

util.AddNetworkString("ShareCards")
util.AddNetworkString("MarkRoundVariant")

--// EVENT properties

local EVENT = {}
local EVENT_VARIANT = {}
local EVENT_REF = nil

EVENT.Title = "A Round Of Yogscast Poker"
EVENT.Description = "Only if the 9 of Diamonds touch!"
EVENT.ExtDescription = "A round of 5-Card Draw Poker (no Texas Hold 'Em, for my sake), bet with your\nhealth. Up to 7 may play. Any pair, three, or four of a kind containing the 9 of\nDiamonds instantly wins."
EVENT.id = "poker"
EVENT.MinPlayers = {Min = 2}
EVENT.Type = EVENT_TYPE_DEFAULT
EVENT.Categories = {"gamemode", "largeimpact", "fun"}

--// My properties

EVENT.NumberOfGames = 0
EVENT.MaxPlayers = 7
EVENT.Started = false
EVENT.Running = false
EVENT.Players = {}
EVENT.ContinuousPlayers = {}
EVENT.Deck = {}
EVENT.PlayerBets = {}

--// EVENT Functions

-- Used to populate EVENT.Players with living players, up to the max amount
function EVENT:GeneratePlayers()
    local removedPlayers = {}
    local playersToPlay = {}

    -- If continuous play is enabled, return the previous player list, clean up any disconnected players, and add in as many new players as possible
    if PokerRandomat.ConVars.EnableContinuousPlay:GetBool() and #self.ContinuousPlayers > 0 then
        playersToPlay = table.Copy(self.ContinuousPlayers)

        local playersToRemove = {}
        for _, ply in ipairs(playersToPlay) do
            if not IsValid(ply) or not ply:Alive() then
                table.insert(playersToRemove, ply)
            end
        end

        for _, ply in ipairs(playersToRemove) do
            table.remove(playersToPlay, table.KeyFromValue(playersToPlay, ply or 0))
        end

        for _, ply in ipairs(player.GetAll()) do
            if not table.HasValue(playersToPlay, ply) then
                table.insert(playersToPlay, ply)
            end
        end
    else
        playersToPlay = self:GetAlivePlayers(true)
    end
    
    local numPlayersOverMax = #playersToPlay - self.MaxPlayers

    while numPlayersOverMax > 0 do
        local removedPlayer = table.remove(playersToPlay)
        table.insert(removedPlayers, removedPlayer)
        numPlayersOverMax = numPlayersOverMax - 1
    end

    for i = 1, #playersToPlay do
        local nextPlayerIndex = (i % #playersToPlay) + 1
        playersToPlay[i].NextPlayer = playersToPlay[nextPlayerIndex]
        playersToPlay[nextPlayerIndex].PrevPlayer = playersToPlay[i]    
        playersToPlay[i].Status = BettingStatus.NONE
    end

    for _, ply in ipairs(removedPlayers) do
        ply:ChatPrint("Sorry " .. ply:Nick() .. ", the maximum number of players was exceeded, and you drew the short stick! The event currently supports up to " .. self.MaxPlayers .. " players.")
    end

    self.Players = playersToPlay
    self.ContinuousPlayers = table.Copy(playersToPlay)
    DynamicTimerPlayerCount = #self.Players
end

-- Called when an event is started. Must be defined for an event to work.
function EVENT:Begin()
    if self.Started then return end

    self.Started = true
    self.NumberOfGames = self.NumberOfGames + 1
    EVENT_REF = self

    self:GeneratePlayers()

    for _, ply in ipairs(self.Players) do
        ply.Status = BettingStatus.NONE
        ply.StoredSteamId = ply:SteamID64()
    end

    net.Start("StartPokerRandomat")
        net.WriteUInt(#self.Players, 3)
        for _, ply in ipairs(self.Players) do
            net.WriteEntity(ply)
        end
    net.Broadcast()

    timer.Create("PokerStartTimeout", PokerRandomat.GetDynamicRoundTimerValue("RoundStateStart"), 1, function()
        if EVENT_REF.Running then return end

        for index, unreadyPly in ipairs(EVENT_REF.Players) do
            if not unreadyPly.Ready then
                EVENT_REF:RemovePlayer(unreadyPly)
            end
        end

        EVENT_REF:StartGame()
    end)
end

-- Called after all players responded to the initial net message and any who haven't are removed
function EVENT:RefreshPlayers()
    if not self.Started then self:End() return end

    net.Start("BeginPokerRandomat")
        net.WriteUInt(#self.Players, 3)
        for _, ply in ipairs(self.Players) do
            net.WriteEntity(ply)
        end
    net.Broadcast()
end

-- Called once all the validated players' clients have responded to BeginPokerRandomat net message
function EVENT:StartGame()
    if not self.Started then self:End() return end

    self:RefreshPlayers()
    self.Running = true

    self.SmallBlind = self.Players[(self.NumberOfGames % #self.Players) + 1]
    self.BigBlind = self.Players[((self.NumberOfGames + 1) % #self.Players) + 1]

    self:RegisterPlayerBet(self.SmallBlind, BettingStatus.RAISE, PokerRandomat.GetLittleBlindBet(), true)
    self:RegisterPlayerBet(self.BigBlind, BettingStatus.RAISE, PokerRandomat.GetBigBlindBet(), true)
    self.BigBlind.Status = BettingStatus.NONE

    net.Start("NotifyBlinds")
        net.WriteEntity(self.SmallBlind)
        net.WriteEntity(self.BigBlind)
    net.Broadcast()

    self:GenerateDeck()
    self:DealDeck()

    timer.Create("CallBeginBetting", PokerRandomat.GetDynamicRoundTimerValue("RoundStateMessage"), 1, function()
        self:BeginBetting(self.BigBlind.NextPlayer)
    end)
end

-- Called to generate a deck of cards and shuffle them
function EVENT:GenerateDeck()
    if not self.Started then self:End() return end

    self.Deck = {}

    for rank = Cards.ACE, Cards.KING do
        for suit = Suits.SPADES, Suits.CLUBS do
            table.insert(self.Deck, {
                Rank = rank,
                Suit = suit
            })
        end
    end

    table.Shuffle(self.Deck)
end

-- Called to deal a generated deck of cards out to all participating players
function EVENT:DealDeck(isSecondDeal)
    if not self.Started then self:End() return end

    for _, ply in ipairs(self.Players) do
        if ply.Status == BettingStatus.FOLD then
            continue
        end

        local deckLength = #self.Deck
        ply.Cards = ply.Cards or {}
        local cardCount = #ply.Cards

        net.Start("DealCards")
            net.WriteUInt(5, 3)
            for i = 1, 5 do
                local card
                if i > cardCount then
                    card = table.remove(self.Deck)
                    ply.Cards[i] = card
                else
                    card = ply.Cards[i]
                end
                net.WriteUInt(card.Rank, 5)
                net.WriteUInt(card.Suit, 3)
            end
            net.WriteBool(isSecondDeal or false)
        net.Send(ply)
    end
end

local function GetNextValidPlayer(ply)
    local startingPlayer = ply
    local toCheck = ply.NextPlayer
    local nextPlayer = nil

    while nextPlayer == nil do
        if toCheck.Status ~= BettingStatus.FOLD then
            nextPlayer = toCheck
        elseif toCheck == startingPlayer then
            error("cannot find next valid player! " .. ply:Nick())
        else
            toCheck = toCheck.NextPlayer
        end
    end

    return nextPlayer
end

-- Called to mark a player as starting their turn to bet
function EVENT:BeginBetting(optionalPlayer)
    if not self.Started then self:End() return end

    self.ExpectantBetter = nil
    if optionalPlayer and optionalPlayer.Status ~= BettingStatus.FOLD then
        self.ExpectantBetter = optionalPlayer
    else
        self.ExpectantBetter = GetNextValidPlayer(optionalPlayer or self.BigBlind)
    end

    if self.ExpectantBetter then
        net.Start("StartBetting")
            net.WriteEntity(self.ExpectantBetter)
        net.Broadcast()

        timer.Create("WaitingOnPlayerBet", PokerRandomat.GetDynamicRoundTimerValue("RoundStateBetting"), 1, function()
            EVENT_REF:RegisterPlayerBet(EVENT_REF.ExpectantBetter, BettingStatus.CHECK, EVENT_REF.PlayerBets[EVENT_REF.ExpectantBetter] or 0)
        end)
    else
        self:EndBetting()
    end
end

local function AllPlayersMatchingBets(ignoreNoStatus)
    local betToCompare = 0
    for _, ply in ipairs(EVENT_REF.Players) do
        if ply.Status == BettingStatus.NONE and not ignoreNoStatus then
            return false
        end

        if ply.Status > BettingStatus.FOLD or (ignoreNoStatus and ply.Status == BettingStatus.NONE) then
            if betToCompare == 0 then -- First bet we run across
                betToCompare = EVENT_REF.PlayerBets[ply]
            elseif betToCompare ~= EVENT_REF.PlayerBets[ply] then -- If there's differences in bet amounts in non-folded players
                return false
            end
        end
    end

    return true
end

local function GetHighestBet()
    local highestBet = 0

    for _, ply in ipairs(EVENT_REF.Players) do
        local newBet = EVENT_REF.PlayerBets[ply]

        if newBet and newBet > highestBet then
            highestBet = newBet
        end
    end

    return highestBet
end

local function ResetOtherPlayersBetStatus(ply)
    for _, other in ipairs(EVENT_REF.Players) do
        if other ~= ply and other.Status ~= BettingStatus.FOLD then
            other.Status = BettingStatus.NONE
        end
    end
end

local function PlayerFolds(ply)
    ply.Status = BettingStatus.FOLD

    net.Start("PlayerFolded")
        net.WriteEntity(ply)
        net.WriteString(ply.StoredSteamId)
    net.Broadcast()
end

local function PlayerChecks(ply)
    ply.Status = BettingStatus.CHECK
    EVENT_REF.PlayerBets[ply] = GetHighestBet()

    net.Start("PlayerChecked")
        net.WriteEntity(ply)
    net.Broadcast()
end

local function PlayerCalls(ply)
    ply.Status = BettingStatus.CALL
    EVENT_REF.PlayerBets[ply] = GetHighestBet()

    net.Start("PlayerCalled")
        net.WriteEntity(ply)
    net.Broadcast()
end

local function PlayerRaises(ply, raise)
    ply.Status = BettingStatus.RAISE
    ResetOtherPlayersBetStatus(ply)
    EVENT_REF.PlayerBets[ply] = raise

    net.Start("PlayerRaised")
        net.WriteEntity(ply)
        net.WriteUInt(raise, 4)
    net.Broadcast()
end

local function EnoughPlayersRemaining()
    local atLeastOne = false
    for _, ply in ipairs(EVENT_REF.Players) do
        if ply.Status ~= BettingStatus.FOLD then
            if atLeastOne then
                return true
            else
                atLeastOne = true
            end
        end
    end

    return false
end

local function CanDispenseWinnings()
    local onePlayerStillAliveWithBets = false

    for _, ply in ipairs(EVENT_REF.Players) do
        if ply:Alive() and EVENT_REF.PlayerBets[ply] then
            if onePlayerStillAliveWithBets then
                return true
            else
                onePlayerStillAliveWithBets = true
            end
        end
    end

    return false
end

-- Called to register a player's bet (or lack thereof)
function EVENT:RegisterPlayerBet(ply, bet, betAmount, forceBet)
    if not self.Started then self:End() return end
    if not IsValid(ply) then return end

    -- If we receive a bet when we're not expecting (and it isn't a fold), ignore it
    if not self.ExpectantBetter and bet > 1 and not forceBet then
        return
    end

    if ply == self.ExpectantBetter or forceBet then
        if ply == self.ExpectantBetter and timer.Exists("WaitingOnPlayerBet") then
            timer.Remove("WaitingOnPlayerBet")
        end

        self.ExpectantBetter = nil
        local highestBet = GetHighestBet()

        if bet < BettingStatus.CHECK then
            PlayerFolds(ply)
        elseif bet == BettingStatus.CHECK then
            if highestBet > betAmount then
                PlayerFolds(ply)
            else
                PlayerChecks(ply)
            end
        elseif bet == BettingStatus.CALL then
            PlayerCalls(ply)
        elseif bet == BettingStatus.RAISE then
            if betAmount <= highestBet then
                PlayerCalls(ply)
            else
                PlayerRaises(ply, betAmount)
            end
        else
            error(ply:Nick() .. " is sending net messages manually...")
        end

        if not forceBet then
            if AllPlayersMatchingBets() then
                net.Start("PlayersFinishedBetting")
                net.Broadcast()

                self:EndBetting()
            else
                local nextPly = GetNextValidPlayer(ply)
                
                self:BeginBetting(nextPly)
            end
        end
    elseif bet < BettingStatus.CHECK then
        -- Out of sync player fold, used primarily for player disconnecting/death
        PlayerFolds(ply)

        if not EnoughPlayersRemaining() then
            if CanDispenseWinnings() then
                self:CalculateWinner()
            else
                net.Start("DeclareNoWinner")
                net.Broadcast()

                timer.Create("CallEventEnd", PokerRandomat.GetDynamicRoundTimerValue("RoundStateMessage"), 1, function()
                    self:End()
                end)
            end
        end
    end
end

function EVENT:EndBetting()
    timer.Create("CallEndBetting", PokerRandomat.GetDynamicRoundTimerValue("RoundStateMessage"), 1, function()
        local epr = EnoughPlayersRemaining() -- This function needs to be ran BEFORE changing player's Status property

        for _, ply in ipairs(self.Players) do
            if ply.Status ~= BettingStatus.FOLD then
                ply.Status = BettingStatus.NONE
            end
        end

        if self.HaveDiscarded or not epr then
            self:CalculateWinner()
        else
            self:BeginDiscarding()
        end
    end)
end

function EVENT:BeginSecoundRoundBetting()
    if not self.Started then self:End() return end

    if AllPlayersMatchingBets(true) and PokerRandomat.IsAllIn(GetHighestBet())then
        self:CalculateWinner()
    else
        self:BeginBetting()
    end
end

function EVENT:BeginDiscarding()
    if not self.Started then self:End() return end

    net.Start("StartDiscard")
    net.Broadcast()

    self.AcceptingDiscards = true

    timer.Create("AcceptDiscards", PokerRandomat.GetDynamicRoundTimerValue("RoundStateDiscarding"), 1, function()
        EVENT_REF:CompletePlayerDiscarding()
    end)
end

local function AllPlayersDiscarded()
    for _, ply in ipairs(EVENT_REF.Players) do
        if not ply.HasDiscarded then
            return false
        end
    end

    return true
end

function EVENT:RegisterPlayerDiscard(ply, discardsTable)
    if not self.Started then self:End() return end

    if not self.AcceptingDiscards then return end

    for _, cardToRemove in ipairs(discardsTable) do
        local toBeRemoved
        for index, cardInHand in ipairs(ply.Cards) do
            if cardToRemove.Rank == cardInHand.Rank and cardToRemove.Suit == cardInHand.Suit then
                toBeRemoved = index
            end
        end

        if toBeRemoved then
            table.remove(ply.Cards, toBeRemoved)
        end
    end

    ply.HasDiscarded = true
    if AllPlayersDiscarded() then
        self:CompletePlayerDiscarding()
    end
end

function EVENT:CompletePlayerDiscarding()
    timer.Remove("AcceptDiscards")
    self.AcceptingDiscards = false
    self.HaveDiscarded = true

    self:DealDeck(true)

    timer.Create("CallBeginSecondRoundBetting", PokerRandomat.GetDynamicRoundTimerValue("RoundStateMessage"), 1, function()
        self:BeginSecoundRoundBetting()
    end)
end

function EVENT:CalculateWinner()
    if not self.Started then self:End() return end

    local winner, hand = self:GetWinningPlayer()

    if winner == nil then
        net.Start("DeclareNoWinner")
        net.Broadcast()
    else
        net.Start("DeclareWinner")
            net.WriteEntity(winner)
            net.WriteString(hand)
        net.Broadcast()

        self:ApplyRewards(winner, hand)
    end

    timer.Create("CallRoundEnd", PokerRandomat.GetDynamicRoundTimerValue("RoundStateEnd"), 1, function()
        if PokerRandomat.ConVars.EnableContinuousPlay:GetBool() and GetRoundState() == ROUND_ACTIVE then
            self:ContinuousPlay()
        else
            self:End()
        end
    end)
end

local function GetHandRank(ply)
    local hand = ply.Cards

    -- Check for flush
    local isFlush = true
    local suit = Suits.NONE
    for _, card in ipairs(hand) do
        if suit == Suits.NONE then
            suit = card.Suit
        elseif suit ~= card.Suit then
            isFlush = false

            break
        end
    end

    -- Check for straights
    local isStraight = true
    local prevRank = Cards.NONE
    local handCopyAsc = table.Copy(hand)
    table.sort(handCopyAsc, function(cardOne, cardTwo)
        return cardOne.Rank < cardTwo.Rank
    end)
    
    for _, card in ipairs(handCopyAsc) do
        if prevRank == Cards.NONE then
            prevRank = card.Rank
        elseif card.Rank ~= prevRank + 1 then
            isStraight = false

            break
        else
            prevRank = card.Rank
        end
    end

    -- Check for kinds
    local suitsByRank = {{}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}}
    local hasThree = false
    local hasThreeRank = Cards.NONE
    local hasPair = false
    local hasTwoPair = false
    local hasPairsRank = Cards.NONE
    for _, card in ipairs(hand) do
        table.insert(suitsByRank[card.Rank], card.Suit)
    end

    for rank, tbl in ipairs(suitsByRank) do
        local count = #tbl
        local rankToCompare = rank
        if rank == Cards.ACE then rankToCompare = Cards.ACE_HIGH end

        if count == 2 then
            if hasPair then
                hasTwoPair = true

                if rankToCompare > hasPairsRank then
                    hasPairsRank = rankToCompare
                end
            else
                hasPair = true
                hasPairsRank = rankToCompare
            end
        elseif count == 3 then
            hasThree = true
            hasThreeRank = rankToCompare
        end
    end

    -- Get highest card rank
    local highestRank = Cards.NONE
    if handCopyAsc[1].Rank == Cards.ACE then
        highestRank = Cards.ACE_HIGH
    else
        highestRank = handCopyAsc[5].Rank
    end

    -- Get table of ranks (used specifically for comparing hands when winning hands are matching pairs or high cards)
    local rankTable = {}

    for _, card in ipairs(handCopyAsc) do
        table.insert(rankTable, card.Rank)
    end

    -- Check possible hands in descending order --

    -- Any pair+ featuring a nine of diamonds
    if PokerRandomat.ConVars.EnableNineDiamondsGag:GetBool() and suitsByRank[Cards.NINE] and #suitsByRank[Cards.NINE] > 1 and table.HasValue(suitsByRank[Cards.NINE], Suits.DIAMONDS) then
        return Hands.NINE_OF_DIAMONDS, 0, 0, {}, "Two+ of a kind with a 9 of diamonds"
    end

    -- Royal flush/straight flush check
    if isFlush and isStraight then
        if handCopyAsc[1].Rank == Cards.ACE then
            return Hands.ROYAL_FLUSH, 0, 0, {}, "a Royal flush"
        else
            return Hands.STRAIGHT_FLUSH, highestRank, 0, {}, "a Straight flush"
        end
    end

    -- Four of a kind
    for rank, suits in pairs(suitsByRank) do
        if #suits == 4 then
            return Hands.FOUR_KIND, rank, 0, {}, "a Four of a kind"
        end
    end

    -- Full house
    if hasPair and hasThree then
        return Hands.FULL_HOUSE, hasThreeRank, 0, {}, "a Full house"
    end

    -- Flush
    if isFlush then
        return Hands.FLUSH, highestRank, 0, {}, "a Flush"
    end

    -- Straight
    if isStraight then
        return Hands.STRAIGHT, highestRank, 0, {}, "a Straight"
    end

    -- Three of a kind
    if hasThree then
        return Hands.THREE_KIND, hasThreeRank, 0, {}, "a Three of a kind"
    end

    -- Two pair
    if hasTwoPair then
        return Hands.TWO_PAIR, hasPairsRank, 0, {}, "Two pairs"
    end

    -- Pair
    if hasPair then
        return Hands.PAIR, hasPairsRank, highestRank, rankTable, "a Pair"
    end

    -- High Card
    return Hands.HIGH_CARD, highestRank, 0, rankTable, "High card"
end

function EVENT:GetWinningPlayer()
    if not self.Started then self:End() return end

    local winningHandRank = Hands.NONE
    local winningPlayer = nil
    local winningHighestCardRank = Cards.NONE
    local winningAltHighestCardRank = Cards.NONE
    local winningRanksTbl = {}
    local winningStr = ""

    local function AssignNewWinner(ply, newHandRank, newHighestCardRank, newAltHighestCardRank, newRanksTbl, newStr)
        winningHandRank = newHandRank
        winningPlayer = ply
        winningHighestCardRank = newHighestCardRank
        winningAltHighestCardRank = newAltHighestCardRank
        winningRanksTbl = newRanksTbl
        winningStr = newStr
    end

    for _, ply in ipairs(self.Players) do
        if ply.Status == BettingStatus.FOLD then
            continue
        end

        local newHandRank, newHighestCardRank, newAltHighestCardRank, newRanksTbl, str = GetHandRank(ply)
        if newHandRank == Hands.NINE_OF_DIAMONDS then
            return ply, str
        elseif newHandRank > winningHandRank then
            AssignNewWinner(ply, newHandRank, newHighestCardRank, newAltHighestCardRank, newRanksTbl, str)
        elseif newHandRank == winningHandRank then
            if newHighestCardRank > winningHighestCardRank then
                AssignNewWinner(ply, newHandRank, newHighestCardRank, newAltHighestCardRank, newRanksTbl, str)
            elseif newHighestCardRank == winningHighestCardRank then
                if newAltHighestCardRank > winningAltHighestCardRank then
                    AssignNewWinner(ply, newHandRank, newHighestCardRank, newAltHighestCardRank, newRanksTbl, str)
                elseif newAltHighestCardRank == winningAltHighestCardRank then
                    for i = 4, 1, -1 do -- Cards should be in ascending order
                        if winningRanksTbl[i] > newRanksTbl[i] then
                            break
                        elseif winningRanksTbl[i] < newRanksTbl[i] then
                            AssignNewWinner(ply, newHandRank, newHighestCardRank, newAltHighestCardRank, newRanksTbl, str)
                            break
                        end
                    end
                end
            end
        end
    end

    return winningPlayer, winningStr
end

local function BetAsPercent(bet)
    if PokerRandomat.ConVars.EnableSmallerBets:GetBool() then
        return bet * 0.10
    else
        return bet * 0.25
    end
end

function EVENT:ApplyRewards(winner, winningHand)
    if not self.Started then self:End() return end
    self.Started = false

    local runningHealth = 0
    for _, ply in pairs(self.Players) do
        if ply ~= winner and ply:Alive() then
            local bet = self.PlayerBets[ply] or 0
            local healthToLose = math.max(math.Round(ply:Health() * BetAsPercent(bet)), 0)
            runningHealth = runningHealth + healthToLose

            if bet > 0 then
                if PokerRandomat.IsAllIn(bet) then
                    ply:Kill()
                else
                    ply:SetHealth(math.max(1, ply:Health() - healthToLose))
                    ply:SetMaxHealth(math.max(1, ply:GetMaxHealth() - healthToLose))
                end
            end
        end
    end

    local cards = ""
    for _, card in ipairs(winner.Cards) do
        cards = cards .. "- " .. PokerRandomat.CardRankToName(card.Rank) .. " of " .. PokerRandomat.CardSuitToName(card.Suit) .. "\n"
    end

    for _, ply in ipairs(player.GetAll()) do
        ply:ChatPrint(winner:Nick() .. " wins the Poker hand with " .. winningHand .. " and gained " .. runningHealth .. " health from all the schmucks who lost!")
        ply:ChatPrint("They had:\n" .. cards)
    end

    winner:SetMaxHealth(winner:GetMaxHealth() + runningHealth)
    winner:SetHealth(winner:Health() + runningHealth)
end

function EVENT:ResetProperties()
    self.Started = false
    self.AcceptingDiscards = false
    self.HaveDiscarded = false
    self.Running = false
    self.Players = {}
    self.Deck = {}
    self.PlayerBets = {}
    self.SmallBlind = nil
    self.BigBlind = nil

    timer.Remove("PokerStartTimeout")
    timer.Remove("WaitingOnPlayerBet")
    timer.Remove("AcceptDiscards")
    timer.Remove("CallEventEnd")
    timer.Remove("CallEndBetting")
    timer.Remove("CallBeginBetting")
    timer.Remove("CallBeginSecondRoundBetting")
    timer.Remove("CallRoundEnd")

    for _, ply in ipairs(player.GetAll()) do
        ply.Cards = {}
        ply.HasDiscarded = false
        ply.Status = BettingStatus.NONE
        ply.NextPlayer = nil
        ply.PrevPlayer = nil
    end
end

function EVENT:ContinuousPlay()
    self:End(true)
    
    timer.Simple(0, function()
        self:Begin()
    end)
end

-- Called when an event is stopped. Used to do manual cleanup of processes started in the event.
function EVENT:End(continuousEnd)
    self:ResetProperties()
    self.ContinuousPlayers = {}

    net.Start("ClosePokerWindow")
        net.WriteBool(continuousEnd or false)
    net.Broadcast()
end

-- Gets tables of the convars defined for an event. Used by the Randomat 2.0 ULX module to dynamically create configuration pages for each event.
function EVENT:GetConVars()
    local sliders = {}
    local checks = {}
    local textboxes = {}

    table.insert(sliders, {
        cmd = "round_state_start",
        dsc = "Manual 'client timeout' duration",
        min = PokerRandomat.ConVars.RoundStateStart:GetMin(),
        max = PokerRandomat.ConVars.RoundStateStart:GetMax()
    })
    table.insert(sliders, {
        cmd = "round_state_betting",
        dsc = "Manual 'betting' phase duration",
        min = PokerRandomat.ConVars.RoundStateBetting:GetMin(),
        max = PokerRandomat.ConVars.RoundStateBetting:GetMax()
    })
    table.insert(sliders, {
        cmd = "round_state_discarding",
        dsc = "Manual 'discarding' phase duration",
        min = PokerRandomat.ConVars.RoundStateDiscarding:GetMin(),
        max = PokerRandomat.ConVars.RoundStateDiscarding:GetMax()
    })
    table.insert(sliders, {
        cmd = "round_state_message",
        dsc = "Manual message duration (should be smaller than all phase durations)",
        min = PokerRandomat.ConVars.RoundStateMessage:GetMin(),
        max = PokerRandomat.ConVars.RoundStateMessage:GetMax()
    })
    table.insert(sliders, {
        cmd = "round_state_end",
        dsc = "Manual post-game wait duration",
        min = PokerRandomat.ConVars.RoundStateEnd:GetMin(),
        max = PokerRandomat.ConVars.RoundStateEnd:GetMax()
    })

    table.insert(checks, {
        cmd = "manual_round_state_times",
        dsc = "Enable use of manual game phase lengths (the above duration sliders)"
    })
    table.insert(checks, {
        cmd = "enable_continuous_play",
        dsc = "Enable continuous play (event repeats until TTT game ends)"
    })
    table.insert(checks, {
        cmd = "enable_smaller_bets",
        dsc = "Reduce bet increments from (default) 25% to 10%"
    })
    table.insert(checks, {
        cmd = "enable_nine_diamonds",
        dsc = "Enable the 9 of Diamonds win condition"
    })
    table.insert(checks, {
        cmd = "enable_yogsification",
        dsc = "Enable the Yogscast sfx"
    })
    table.insert(checks, {
        cmd = "enable_audio_cues",
        dsc = "Enable the round state audio cues (disabling overrides yogsification state)"
    })

    return sliders, checks, textboxes
end

function EVENT:RemovePlayer(ply)
    table.remove(self.Players, table.KeyFromValue(self.Players, ply) or 0)
    self.PlayerBets[ply] = nil

    if #self.Players < self.MinPlayers then
        self:End()
        
        for _, ply in ipairs(player.GetAll()) do
            ply:ChatPrint("Too few players remain to continue the poker game, cancelling the poker game!")
        end
    end
end

--// Net Receives

local function AllPlayersReady(playerTable)
    for _, ply in ipairs(playerTable) do
        if not ply:IsBot() and (ply.Ready == nil or not ply.Ready) then
            return false
        end
    end

    return true
end

net.Receive("StartPokerRandomatCallback", function(len, ply)
    if EVENT_REF.Started and not EVENT_REF.Running then
        ply.Ready = true

        if AllPlayersReady(EVENT_REF.Players) then
            EVENT_REF:StartGame()
        end
    end
end)

net.Receive("MakeBet", function(len, ply)
    if EVENT_REF.Started then
        local bet = net.ReadUInt(3)
        local betAmt = net.ReadUInt(4)

        EVENT_REF:RegisterPlayerBet(ply, bet, betAmt)
    end
end)

net.Receive("MakeDiscard", function(len, ply)
    if EVENT_REF.Started then
        if not EVENT_REF.AcceptingDiscards then return end

        local cardsBeingDiscarded = {}
        local numCards = net.ReadUInt(2)

        for i = 1, numCards do
            table.insert(cardsBeingDiscarded, {
                Rank = net.ReadUInt(5),
                Suit = net.ReadUInt(3)
            })
        end

        EVENT_REF:RegisterPlayerDiscard(ply, cardsBeingDiscarded)
    end
end)

--// Hooks

local function HandlePokerPlayerDeath(ply)
    if (not ply or not IsValid(ply)) or ((EVENT and not EVENT.Started) and (EVENT_VARIANT and not EVENT_VARIANT.Started)) then return end

    if EVENT_REF.Started then
        if table.HasValue(EVENT_REF.Players, ply) then
            EVENT_REF:RegisterPlayerBet(ply, BettingStatus.FOLD, Bets.NONE)
            EVENT_REF:RemovePlayer(ply)
        end
    end
end

hook.Add("PlayerDeath", "Player Death Folds In Poker", HandlePokerPlayerDeath)
hook.Add("PlayerSilentDeath", "Silent Player Death Folds In Poker", HandlePokerPlayerDeath)

hook.Add("PlayerDisconnected", "Alter Poker Randomat If Player Leaves", function(ply)
    if (not ply or not IsValid(ply)) or ((EVENT and not EVENT.Started) and (EVENT_VARIANT and not EVENT_VARIANT.Started)) then return end

    if EVENT_REF.Started then
        local prevPlayer = ply.PrevPlayer
        local nextPlayer = ply.NextPlayer

        prevPlayer.NextPlayer = nextPlayer
        nextPlayer.PrevPlayer = prevPlayer

        HandlePokerPlayerDeath(ply)
    end
end)

hook.Add("PlayerSay", "LoganDebugCommands", function(ply, msg)
    if EVENT_REF.Started and ply:IsSuperAdmin() then
        local stringSplit = string.Split(string.lower(msg), " ")
        local stringCheck = stringSplit[1]

        if string.StartWith(stringCheck, "!fold") then
            EVENT_REF:RegisterPlayerBet(EVENT_REF.ExpectantBetter, BettingStatus.FOLD, Bets.NONE)
        elseif string.StartWith(stringCheck, "!check") then
            EVENT_REF:RegisterPlayerBet(EVENT_REF.ExpectantBetter, BettingStatus.CHECK, GetHighestBet())
        elseif string.StartWith(stringCheck, "!call") then
            EVENT_REF:RegisterPlayerBet(EVENT_REF.ExpectantBetter, BettingStatus.CALL, GetHighestBet())
        elseif string.StartWith(stringCheck, "!raise") then
            EVENT_REF:RegisterPlayerBet(EVENT_REF.ExpectantBetter, BettingStatus.RAISE, tonumber(stringSplit[2])) -- values match Bets/Bets_Alt in sh_poker
        elseif string.StartWith(stringCheck, "!end") then
            EVENT_REF:End()
        end
    end
end)

Randomat:register(EVENT)

--// WOMEN ARE COLLUDING VARIANT

EVENT_VARIANT = table.Copy(EVENT)
EVENT_VARIANT.Title = "A Suspicious Round Of Yogscast Poker"
EVENT_VARIANT.Description = "The women are colluding!"
EVENT_VARIANT.ExtDescription = "A variant game of Yogscast Poker, but the women are colluding. Uses the\nnon-variant mode's ConVars"
EVENT_VARIANT.id = "poker_colluding"
EVENT_VARIANT.MinPlayers = 3

function EVENT_VARIANT:StartGame()
    if not self.Started or EVENT.Started then return end -- Difference

    net.Start("MarkRoundVariant") -- Difference
    net.Broadcast()

    self:RefreshPlayers()
    self.Running = true

    self.SmallBlind = self.Players[(self.NumberOfGames % #self.Players) + 1]
    self.BigBlind = self.Players[((self.NumberOfGames + 1) % #self.Players) + 1]

    self:RegisterPlayerBet(self.SmallBlind, BettingStatus.RAISE, PokerRandomat.GetLittleBlindBet(), true)
    self:RegisterPlayerBet(self.BigBlind, BettingStatus.RAISE, PokerRandomat.GetBigBlindBet(), true)
    self.BigBlind.Status = BettingStatus.NONE

    net.Start("NotifyBlinds")
        net.WriteEntity(self.SmallBlind)
        net.WriteEntity(self.BigBlind)
    net.Broadcast()

    self:GenerateDeck()
    self:DealDeck()
    self:GenerateCollusions() -- Differences
    self:ShareHands() -- Difference

    timer.Create("CallBeginBetting", PokerRandomat.GetDynamicRoundTimerValue("RoundStateMessage"), 1, function()
        self:BeginBetting(self.BigBlind.NextPlayer)
    end)
end

function EVENT_VARIANT:GenerateCollusions()
    if not self.Started then self:End() return end

    local playerCount = #self.Players
    self.ColludingPlayers = {}

    if PokerRandomat.ConVars.EnableRandomCollusions:GetBool() then
        local randomPlayers = table.Copy(self.Players)
        table.Shuffle(randomPlayers)

        for i, ply in pairs(randomPlayers) do
            self.ColludingPlayers[ply] = randomPlayers[(i + 1) % #randomPlayers]
        end
    else
        for _, ply in pairs(self.Players) do
            self.ColludingPlayers[ply] = ply.PrevPlayer
        end
    end
end

function EVENT_VARIANT:ShareHands()
    if not self.Started then self:End() return end

    for ply1, ply2 in pairs(self.ColludingPlayers) do
        net.Start("ShareCards")
            net.WriteEntity(ply2)
            for i, card in ipairs(ply2.Cards) do
                net.WriteUInt(card.Rank, 5)
                net.WriteUInt(card.Suit, 3)
            end
        net.Send(ply1)
    end
end

function EVENT_VARIANT:RemovePlayer(ply)
    table.remove(self.Players, table.KeyFromValue(self.Players, ply) or 0)
    self.PlayerBets[ply] = nil

    -- Default min players is 3 since it makes the variant rules pointless to start the game with only two players (just play default)
    -- However, Since each player's colluded "partner" is unknown, the game can continue with just two players should up to the third die
    if #self.Players < 2 then -- Difference
        self:End()
        
        for _, ply in ipairs(player.GetAll()) do
            ply:ChatPrint("Too few players remain to continue the poker game, cancelling the poker game!")
        end
    end
end

function EVENT_VARIANT:CompletePlayerDiscarding()
    timer.Remove("AcceptDiscards")
    self.AcceptingDiscards = false
    self.HaveDiscarded = true

    self:DealDeck(true)
    self:ShareHands() -- Difference

    timer.Create("CallBeginSecondRoundBetting", PokerRandomat.GetDynamicRoundTimerValue("RoundStateMessage"), 1, function()
        self:BeginSecoundRoundBetting()
    end)
end

function EVENT_VARIANT:GetConVars()
    local sliders = {}
    local checks = {}
    local textboxes = {}

    table.insert(checks, {
        cmd = "enable_random_collusions",
        dsc = "Enable random (versus ordered) collusion partners"
    })
    table.insert(checks, {
        cmd = "anonymized_collusions",
        dsc = "Hides the collusion partner's name"
    })

    return sliders, checks, textboxes
end

Randomat:register(EVENT_VARIANT)