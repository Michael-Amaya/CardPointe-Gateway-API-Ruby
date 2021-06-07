require "base64"
require "json"
require "rest-client"

# Cardpointe gateway driver
# Written by Michael Amaya

class CardPointeGateway
    # Ability to write custom requests to custom endpoints with custom method
    # Call process() after setting all 3
    attr_writer :request, :endpoint, :method
    attr_reader :merchant_id, :request, :response, :endpoint

    # Set site, merchant id, username, password
    # and create initial variables
    def initialize(account_info = {})
        @site = account_info[:site]
        @merchant_id = account_info[:merchant_id]
        @username = account_info[:username]
        @password = account_info[:password]
        @credentials = get_credentials()

        @server = "https://#{@site}.cardconnect.com/cardconnect/rest/"
        @request = {}.to_json
        @response = {}.to_json
    end

    # Creates credentials for rest login
    def get_credentials()
        Base64.encode64("#{@username}:#{@password}")
    end

    # Set this to the reader output
    def reader_dump(data)
        @request = {
            "merchid" => @merchant_id,
            "track" => data,
        }
    end

    def manual_entry(card_number, expiry, cvv, postal)
        @request = {
            "merchid" => @merchant_id,
            "account" => card_number,
            "expiry" => "#{expiry}", ## MMYY format
            "cvv2" => cvv,
            "postal" => postal
        }
    end

    # Creates a sale, need to run process() to run the sale
    # Running reader_dump after sale creates bug, should be
    # reader_dump(data) -> sale(amount, capture)
    def sale(amount, capture = "y")
        @endpoint = "auth"
        @method = "post"

        @request["amount"] = amount
        @request["capture"] = capture
        @request = @request.to_json
    end

    # for dumping and creating a sale at once
    def dump_and_sale(data, amount, capture = "y")
       reader_dump(data)
       sale(amount, capture) 
    end

    # Sets up a refund, but may fail if an order is not
    # refundable
    # Order may not be refundable if it has been voided, or if it is
    # voidable
    def refund(retref)
        @endpoint = "refund"
        @method = "post"
        
        @request = {
            "merchid" => @merchant_id,
            "retref" => retref
        }.to_json
    end

    # Sets up a void, but may fail if order is not voidable, if it
    # has been voided or refunded (Haven't tested the refunded part)
    def void(retref)
        @endpoint = "void"
        @method = "post"

        @request = {
            "merchid" => @merchant_id,
            "retref" => retref
        }.to_json
    end

    # Checks to see if order is voidable. If it is, setup a void or refund
    # then process
    def refund_or_void!(retref)
        if is_voidable?(retref)
            void(retref)
        else
            refund(retref)
        end

        process()
    end

    # Checks to see if an order is voidable
    def is_voidable?(retref)
        inquire(retref)
        is_voidable = get_value_of("voidable")

        is_voidable == "Y"
    end

    # Gets some basic data on an order, like voidable, last four of card,
    # expiry, etc etc
    def inquire(retref)
        @endpoint = "inquire/#{retref}/#{@merchant_id}"
        @method = "get"

        process()
    end

    # Gets the reference number of the last order processed
    def get_retref_of_last()
        get_value_of("retref")
    end

    # Gets last four of card of last request processed
    def get_last_four_of_last()
        get_value_of("lastfour")
    end

    # Gets expiry of card of last request processed
    def get_expiry_of_last()
        get_value_of("expiry")
    end

    # Gets the value of key for the last response
    def get_value_of(key)
        JSON.parse(@response)[key]
    end

    # Sends the request to the server, using post or get
    def process()
        get() if @method == "get" 
        post() if @method == "post"
        @response
    end

    # Uses get to process request
    def get()
        @response = RestClient.get(
            "#{@server}#{@endpoint}",
            :Host => @site,
            :Authorization => "Basic #{@credentials}",
            :Content_Type => "application/json"
        )
    end

    # Uses post to process request
    def post()
        @response = RestClient.post(
            "#{@server}#{@endpoint}",
            @request,
            :Host => @site,
            :Authorization => "Basic #{@credentials}",
            :Content_Type => "application/json"
        )
    end
end