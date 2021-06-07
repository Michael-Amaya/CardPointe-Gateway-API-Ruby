require_relative("./lib/cardpointe_gateway")

# Test info from https://support.cardpointe.com/gateway-test-credentials
SITE = "fts-uat"
MERCHANT_ID = "496160873888"
USERNAME = "testing"
PASSWORD = "testing123"

payment = CardPointeGateway.new(
    site: SITE,
    merchant_id: MERCHANT_ID,
    username: USERNAME,
    password: PASSWORD
)

# Get card data and create a sale

payment.reader_dump("track data")
payment.sale("1.50")

puts "Processing sale"
# Get the response and put into console
response = payment.process()
puts response

puts "Processing refund"
#Setup a refund or void of last order and put into console
response = payment.refund_or_void!(payment.get_retref_of_last())
puts response

puts "Setting up manual entry"
payment.manual("card number", "Expiry in MMYY", "CVV2", "Postal code")
payment.sale("1.50")
response = payment.process()

puts "Processing manual entry refund"
response = payment.refund_or_void!(payment.get_retref_of_last())
puts response