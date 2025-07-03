require 'nokogiri'
require 'open-uri'
require 'csv'
require 'json'

# Base URL of the book details page
base_url = 'https://www.tunisian-books.com/Livre?ID='
start_id = (ARGV[0] || 1).to_i
end_id = (ARGV[1] || 1895).to_i

# Array to hold book data
books = []
(start_id..end_id).each do |id|

# Loop through IDs from 1 to 1885
#(1..1895).each do |id|
  # Construct the URL for the current book
  book_url = "#{base_url}#{id}"

  begin
    # Open the book page
    book_doc = Nokogiri::HTML(URI.open(book_url))

    # Extract book details
    title = book_doc.at_css('.title-book')&.text&.strip
# Skip if the title is empty
  
    author = book_doc.at_css('.auteur-book')&.text&.strip ||  "N/A"
    publisher = book_doc.at_css('.categorie-book span b:contains("الناشر :") + a')&.text&.strip  ||  "N/A"
    category = book_doc.at_css('.categorie-book span b:contains("التصنيف :") + a')&.text&.strip  ||  "N/A"
    price = book_doc.at_css('.prix-book')&.text&.strip

    # Replace '$' with 'TND' if found, otherwise set to 'N/A'
    price = price && !price.empty? ? price.gsub('$', 'TND') : 'N/A'

    summary = book_doc.at_css('.description-book')&.text&.strip  ||  "N/A"
    year = book_doc.at_css('tr td.tech-book-sp:nth-child(3)')&.text&.strip  ||  "N/A"
    isbn = book_doc.at_css('tr td.tech-book-sp:nth-child(4)')&.text&.strip  ||  "N/A"
    image_src = book_doc.at_css('img.image-produit')['src'] rescue nil 
    # Construct the full image URL
# Construct the full image URL (assuming base_url already includes the domain)
    #image_url = "#{image_src}" if image_src
img_url = 'https://tunisian-books.com/'
image_url = "#{img_url}#{image_src}" if image_src

    # Skip if the title is empty
    next if title.nil? || title.empty?

    # Add the book data to the array
    books << {
      title: title,
      author: author,
      publisher: publisher,
      category: category,
      year: year,
      url: book_url,
      price: price,
      isbn: isbn,
      summary: summary,
      image_url: image_url
    }

    # Print book details (optionally)
    puts "Title: #{title}"
    puts "Author: #{author}"
    puts "Publisher: #{publisher}"
    puts "Category: #{category}"
    puts "Year: #{year}"
    puts "URL: #{book_url}"
    puts "Price: #{price}"
    puts "ISBN: #{isbn}"
    puts "Summary: #{summary}"
    puts "Image URL: #{image_url}" 
    puts "-" * 40 
sleep(rand(1..2))

  rescue OpenURI::HTTPError => e
    puts "Failed to open #{book_url}: #{e.message}"
  rescue StandardError => e
    puts "An error occurred while processing #{book_url}: #{e.message}"
  end
end

# Write the data to a CSV file
CSV.open('books.csv', 'w') do |csv|
  csv << ['Title', 'Author', 'Publisher', 'Category', 'Year', 'URL', 'Price', 'ISBN', 'Summary', 'Image URL']
  books.each do |book|
    csv << [book[:title], book[:author], book[:publisher], book[:category], book[:year], book[:url], 
             book[:price], book[:isbn], book[:summary], book[:image_url]]
  end
end

# Write the data to a JSON file
#File.write('books.json', JSON.pretty_generate(books)) 
File.write("books_chunk_#{start_id}_#{end_id}.json", JSON.pretty_generate(books))


puts "Scraping completed! #{books.size} books saved to books.csv and books.json."