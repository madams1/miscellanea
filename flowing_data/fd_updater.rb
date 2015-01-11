#!/usr/bin/env ruby

require "nokogiri"
require "open-uri"
require "mongo"
require "date"

include Mongo


db_name = "flowing_data"
coll_name = "posts"
db = MongoClient.new("192.168.11.3", 27017).db(db_name)
# db = MongoClient.new().db(db_name)
posts = db.collection(coll_name)

most_recent_page = "http://flowingdata.com/page/1"


# add posts to flowing_data database
# that occurred after the current most recent post
most_recent_post = posts.find.sort(_id: :desc).limit(1).to_a[0]

# start scraping
page = Nokogiri::HTML(open(most_recent_page))

# keep track of the number of new posts
post_count = 0

page.css("#recent-posts li.archive-post").reverse.each { |post|

    doc = {} # initialize each document
    doc[:title] = post.css("h3 a").text.strip

    # skip the posts that already exist in the collection
    next if posts.find(title: "#{doc[:title]}").to_a.length > 0

    # count the number of posts getting added
    post_count += 1

    # link and date
    post.css("h3 a[rel='bookmark']").each { |link|
        doc[:link] = link['href']

        date_string = link['href'][/com\/([0-9]*\/[0-9]*\/[0-9]*)/, 1]
        doc[:date] = Time.strptime(date_string, "%Y/%m/%d").utc
    }

    # posted to category
    doc[:posted_to] = []
    post.css("a[rel='category tag']").each { |pt|
        doc[:posted_to].push(pt.text)
    }

    # tags
    doc[:tags] = []
    post.css(".meta-bar a[rel='tag']").each { |tag|
        doc[:tags].push(tag.text)
    }

    # image
    post.css(".archive-featured-image img").each { |img|
        doc[:image] = img['src']
    }

    # remove tags array from collection if it's empty
    doc.delete(:tags) if doc[:tags].empty?

    # add doc to posts collection
    id = posts.insert(doc)

}

# completion message
puts post_count > 0 ?
"#{DateTime.now} => Added #{post_count} new document(s) to the #{coll_name} collection in the #{db_name} database!\n" :
"#{DateTime.now} => No new posts.\n"
