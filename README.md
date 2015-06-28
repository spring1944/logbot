# logbot
simple IRC bot to serve github notifications and such for the S44 project, but written (so far) in a fairly general way.

##usage
clone, create logbot.conf with contents like this:

    {
	  orgs => {
	    <github organization login> => {
		  github => {
			webhook_secret => 'something secret that went into the GH webhook interface',
		  },
		  channels => [ '#channelOne', '#channelTwo' ],
		},
		<other github organization login> => {
		   ... same as first, but different secret and channels
		}
	  },

      irc => {
        nick => 'LogBot',
        user => 'logbotUser',
        pass => 'something secret that identifies the user on the IRC server',
        server => 'irc.coolircserver.com:6667'
      }
    };

then, run it with:

    ./script/logbot daemon -m production -l http://*:8080

...a wild bot appears!

## tech
based on Mojolicious and Mojo::IRC

## TODO
* add more events to the github handler
* log chat, provide a simple interface to look at it/search it
* tests that don't involve running cURL
