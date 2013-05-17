# === Faye client, to send messages
# 
# == Usage
# Just start and send content from CLI to any public channel.
#

faye = require 'faye'
readline = require 'readline'


# Instantiate Faye client
client = new faye.Client 'http://localhost:8000/faye'


# Create a readline interface
rl = readline.createInterface
    input:  process.stdin,
    output: process.stdout


# Leaves the process with clean readline
cleanExit = ->
    console.log('\n')
    rl.close()
    process.exit(0)


# Handle ^C
rl.on 'SIGINT', cleanExit


# Read input
readInput = ->
    # Prompt for a message to send
    rl.question 'Send (channel data):', (input) ->
        if (input.length == 0)
        	# Offer to exit on empty input
            rl.question 'Can\'t send empty message. Do you want to exit? (Y/n): ', (answer) ->
                cleanExit() unless (answer.match /^n(o)?$/i)
        else
            # Reformat
            [channel, words...] = input.split ' '
        
            if (words.length == 0)
                # Handle empty messages
                data = {}
            else
                # Parse JSON
                data = JSON.parse words.join ' '
        
            # Send
            client.publish channel, data
                
        # Wait for new input
        readInput()


# Begin loop
readInput()
