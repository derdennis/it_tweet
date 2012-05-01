#!/usr/bin/env ruby

# This script takes information from an RSS feed and posts it as updates to
# Twitter. If you have a website or blog, you can just run this script every
# time you make a new post and it'll automatically tweet about it. 
#
# This script is heavily based on the twitterscript2 by Michael Morin which can
# be found at:
#
# http://ruby.about.com/od/networking/qt/twitterscript2.htm
#
# The main configuration options are expected in config.yml in the same
# directory as this script. 

# Require some gems
require 'rubygems'
require 'twitter'
require 'simple-rss'
require 'open-uri'
require 'yaml'
require 'pony'

# Determine directory in which we live
@script_dir = File.expand_path(File.dirname(__FILE__))

# Load config from yaml-file, find it in the @script_dir
CONFIG = YAML.load_file("#{@script_dir}/config.yml") unless defined? CONFIG

# Feed is here
feed = CONFIG['feed']
# Cache file for the last checked time is here
tweet_times_file = @script_dir + "/" + CONFIG['cache_file']

# Configure my OAuth for Twitter authentification, the actual keys live in
# config.yml
Twitter.configure do |config|
  config.consumer_key = CONFIG['consumer_key']
  config.consumer_secret = CONFIG['consumer_secret']
  config.oauth_token = CONFIG['oauth_token']
  config.oauth_token_secret = CONFIG['oauth_token_secret'] 
end

# If the tweet_times file exists, load the content from the yaml into a hash
# else create a new one and date it on 1970.
tweet_times = if File.exists?(tweet_times_file)
                YAML.load( File.read(tweet_times_file) )
            else
                Hash.new( Time.mktime('1970') )
            end

# Fetch and parse the feed with SimpleRSS
rss = SimpleRSS.parse open(feed) 

# Tell me you're actually doing something...
print "Checking ", feed,  " for tweetable posts...", "\n"

# Walk the feed in reverse so we see the oldest entry first
rss.entries.reverse.each_with_index do|i,idx|
    #If the publication date is later than the date in our hash, put it's
    #values into the text for a new tweet.
    if i.updated > tweet_times[feed]
        text = "New Blogpost: #{i.title} #{i.link}"
        # Output the text
        puts text
        puts "=" * 50
        # Tweet the text
        Twitter.update text

        # Notify me via mail that the post was tweeted
        message = "Hi #{CONFIG['recipient_name']}, \n\n I just tweeted the following tweet: \n\n" + text.to_s + ". \n\n Best, \n\n #{CONFIG['from_name']}"
        subject = "New Tweet tweeted: " + i.title.to_s
        # Pony configuration for googlemail, reads almost all values from
        # config.yml
        Pony.mail({
            :to => CONFIG['recipient_mail'],
            :from => CONFIG['from_mail'],
            :subject => subject,
            :body => message,
            :via => :smtp,
            :via_options => {
            :address              => CONFIG['smtp_server'],
            :port                 => CONFIG['smtp_port'],
            :enable_starttls_auto => true,
            :user_name            => CONFIG['smtp_user'],
            :password             => CONFIG['smtp_password'],
            :authentication       => :plain, 
            :domain               => "localhost.localdomain" 
        } # End pony via options
        }) # End Pony.mail

        # Update the hash with the time from the post just twittered
        tweet_times[feed] = i.updated
        # Write the hash back to the cache file
        File.open( tweet_times_file, 'w' ) do|f|
            f.write YAML.dump(tweet_times)
        end
        
        # Sleep for 60 seconds
        sleep 60
    end # End if i.updated
end # End rss.entries.reverse

