twitch_display_lines = {}
gui = gui or GuiCreate()
xpos = xpos or 80
ypos = ypos or 30
randomOnNoVotes = false
math.randomseed(os.time())

function draw_twitch_display()
  GuiStartFrame( gui )
  GuiLayoutBeginVertical( gui, xpos, ypos )
  for idx, line in ipairs(twitch_display_lines) do
    GuiText(gui, 0, 0, line)
  end
  GuiLayoutEnd( gui )
end

function set_countdown(timeleft)
  twitch_display_lines = {"Next vote: " .. timeleft .. "s"}
end

outcomes = {}
function clear_outcomes()
  outcomes = {}
end

function clear_display()
  twitch_display_lines = {}
end

function add_outcome(outcome)
  table.insert(outcomes, outcome)
end

outcome_generators = {}

function draw_outcomes(n)
  local candidates = {}
  for idx, generator in ipairs(outcome_generators) do
    candidates[idx] = {math.random(), generator}
  end
  table.sort(candidates, function(a, b) return a[1] < b[1] end)
  clear_outcomes()
  for idx = 1, n do
    add_outcome(candidates[idx][2]())
  end
end

function update_outcome_display(vote_time_left)
  twitch_display_lines = {"Voting ends: " .. vote_time_left}
  for idx, outcome in ipairs(outcomes) do
    table.insert(
      twitch_display_lines,
      ("%d> %s (%d)"):format(idx, outcome.name, outcome.votes) 
    )
  end
end

function set_votes(outcome_votes)
  for idx, outcome in ipairs(outcomes) do
    outcome.votes = outcome_votes[idx] or 0
  end
end

function do_winner()
  local best_outcome = outcomes[1]
  for idx, outcome in ipairs(outcomes) do
    if outcome.votes > best_outcome.votes then
      best_outcome = outcome
    end
  end
  if best_outcome.votes > 0 then
    GamePrintImportant(best_outcome.name, best_outcome.desc or "you voted for this")
    best_outcome:func()
  elseif randomOnNoVotes then
    local random_outcome = outcomes[math.random(1, 4)]
    GamePrintImportant("Nobody voted!", "Random option choosen: " .. random_outcome.name)
    random_outcome:func()
  else
    GamePrintImportant("Nobody voted!", "Remember to vote!")
  end
  clear_outcomes()
  clear_display()
end

add_persistent_func("twitch_gui", draw_twitch_display)