## script to initially populate mongodb collection with all flowing data posts

require "nokogiri"
require "open-uri"
require "mongo"

include Mongo

db = MongoClient.new("192.168.11.3", 27017).db("flowing_data")
# db = MongoClient.new().db("flowing_data")
posts = db.collection("posts")

# remove records if any exist
posts.remove

base_url = "http://flowingdata.com/page/"
first_page = Nokogiri::HTML(open(base_url + "1"))
last_pg_num = first_page.css(".first_last_page").text.to_i

# start scraping all the pages
puts "Seeding MongoDB with FlowingData posts. Please be patient.\n\n"

for pg_num in last_pg_num.downto(1) do

    print "Scraping #{last_pg_num} pages... [ #{(((last_pg_num - pg_num)/last_pg_num.to_f)*100).round(1)}% ]\r"

    page = Nokogiri::HTML(open(base_url + "#{pg_num}"))

    # look at each post
    page.css("#recent-posts li.archive-post").reverse_each { |post|
        doc = {}
        doc[:title] = post.css("h3 a").text.strip

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

end
