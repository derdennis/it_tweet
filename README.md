# it_tweet.rb README #

This script reads an RSS-feed and tweets new entries to a Twitter account. It was created, to announce new posts to [instant-thinking.de](http://instant-thinking.de/) but could be of some use for other [Octopress](http://octopress.org/)-blogs too.

If you decide to use it, just go ahead and `fork`/`clone` from Github to some place on your computer. 

You then have to remove the `.example` extension from the config file and from the LaunchAgent-`plist`, to make them usable.

The feed-variable in `config.yml` obviously gets filled with your feed-address. 

You'll have to obtain your Twitter-OAuth-credentials by registering an app at [Twitters developer site](https://dev.twitter.com/apps) and copy & paste them to your config file. 

The mail settings are pre-configured for [Google-Mail](http://mail.google.com/), if you got a Gmail-account you'll simply have to insert your `username@googlemail.com` address and password in the `from`- and `smtp`-fields. Configuration for any other mail-provider is left as an exercise to the reader and will probably require some work on the `pony` section in the script itself…   

When you finished the config you can execute the script. It should start to tweet the items of your feed to your Twitter-stream. 

Of course, you'll want to automate the execution with `cron` or `launchd`.

See this [blogpost](http://instant-thinking.de/2012/05/08/tweeting-a-new-octopress-post-to-twitter/) for more information and a launchd Example...
