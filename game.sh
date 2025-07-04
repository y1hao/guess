#!/usr/bin/env bash

# set -x
set -euo pipefail

export MODEL="o4-mini"

export RULES="
In this game, the player needs to guess a word with the help of the AI.
The player can ask the AI questions related to the word or guess the word directly.
The AI will respond with a hint or confirm if the guess is correct.
"

export GENERATOR_SYSTEM_PROMPT=$(echo "
You are a word-guessing game generator. Your task is to create a list of words that
can be used in a word-guessing game.

Here are the rules of the game:
$RULES

You need to generate a list of 30 words that are suitable for this game. The words should be
common enough to be guessed by a player, but not too obvious. The words should be be straightforward
and not too complex, at the difficulty level that a second language learner would be able to guess them.
Please provide the list of words in a JSON array format, like this:
[
  \\\"word1\\\",
  \\\"word2\\\",
  \\\"word3\\\"
]" | tr '\n' ' ')

export RESPONDER_SYSTEM_PROMPT=$(echo "
You are a word-guessing game responder. Your task is to respond to the player's guesses
and hints in a word-guessing game.

Here are the rules of the game:
$RULES

The word that the player is trying to guess is: \\\"<ANSWER>\\\".

You will receive a question or a guess from the player. If the player asks a question,
you must respond to that question related to the word with a hint or information that
helps the player to guess the word. The hints should be relevant and helpful, but not too
obvious. You should not reveal the word directly.

If the player asks for a hint that you don't know, you should respond with
\\\"I'm not sure about that. Can you ask for a different question?\\\".

If the player makes a guess, if the guess is correct, you should respond with
\\\"Congratulations! That's the correct answer. Enter 'q' to exit the game.\\\".
If the guess is incorrect, you should respond with
\\\"Sorry, that's not correct. Try again!\\\".

It's very important that you must not reveal the word directly.
" | tr '\n' ' ')

function title    { echo -e "  \033[1;32m$1\033[0m"; } # bold green
function describe { echo -e "  \033[32m$1\033[0m";   } # green
function system   { echo -e "  \033[34m$1\033[0m";   } # blue
function warning  { echo -e "  \033[33m$1\033[0m";   } # yellow
function emphasis { echo -e "  \033[1;33m$1\033[0m"; } # bold yellow
function info     { echo -e "  \033[90m$1\033[0m";   } # grey

function invoke {
  local system_prompt="$1"
  local user_prompt="$2"
  curl -s -X POST https://api.openai.com/v1/chat/completions \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"$MODEL\",
      \"messages\": [
        {
          \"role\": \"system\",
          \"content\": \"$system_prompt\"
        },
        {
          \"role\": \"user\",
          \"content\": \"$user_prompt\"
        }
      ]
    }" | jq -r '.choices[0].message.content'
}

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  warning "OPENAI_API_KEY must be set to play the game."
  exit 1
fi

echo
title "Welcome to the Word Guessing Game!"
while read -r line; do
  describe "$line"
done < <(echo "$RULES")
describe "Enjoy!"
echo

# First call AI to generate a list of words instead of only one, then we randomly select one from the list.
# This is to make it less likely that AI will repeatedly generate the same simple words like "apple".
info "Generating the word ..."
echo

WORDS=($(invoke "$GENERATOR_SYSTEM_PROMPT" "Please generate a list of words for the game." | jq -r '.[]'))
COUNT=${#WORDS[@]}
INDEX=$((RANDOM % COUNT))
WORD="${WORDS[$INDEX]}"

info "Done. You can start asking questions or guessing the word."
info "Type 'q' to exit the game and see the word."
echo

# Start the game loop
while true; do
  read -p "  >>> " INPUT

  if [[ -z "$INPUT" ]]; then
    continue
  fi

  if [[ "$INPUT" == "q" ]]; then
    describe "Thanks for playing! Goodbye!"
    echo
    break
  fi

  PROMPT=$(echo "$RESPONDER_SYSTEM_PROMPT" | sed "s/<ANSWER>/$WORD/")
  invoke "$PROMPT" "$INPUT" | while read -r line; do
    system "$line"
  done
  echo
done

warning "Game ends. The word was:"
emphasis "$WORD"
echo