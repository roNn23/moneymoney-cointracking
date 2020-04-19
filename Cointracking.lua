WebBanking {
    version = 1.6,
    url = "https://cointracking.info/",
    services = { "CoinTracking" }
}

MAX_STATEMENTS_PER_PAGE = 300
MINTOS_DATE_PATTERN = "(%d+)%.(%d+)%.(%d+)"

local username
local password

function SupportsBank (protocol, bankCode)
    return protocol == ProtocolWebBanking and bankCode == "CoinTracking"
end

local function login ()
    local html = HTML(connection:get("https://cointracking.info/"))
    html:xpath("//input[@id='log_us']"):attr("value", username)
    html:xpath("//input[@id='log_pw']"):attr("value", password)

    html = HTML(connection:request(html:xpath("//form[@id='form_login']//input[@name='login']"):click()))

    return html
end

local function loginStep1()
    local html = login ();
    local headline = html:xpath("//h1"):text()

    if string.match(headline, "Error") then
      return LoginFailed
    end

    if headline == "Enter your 2-Step Verification Code" then
      return {
        title = "Two-factor authentication",
        challenge = "Enter the two-factor authentication code provided by the Authenticator app.",
        label = "6-digit code"
      }
    end
end


local function sendTwoFactorCode (twoFactorCode)
    local html = login()

    local headline = html:xpath("//h1"):text()

    html:xpath("//input[@name='code_2fa']"):attr("value", twoFactorCode)

    html = HTML(connection:request(html:xpath("//input[@name='check_2fa']"):click()))

    headline = html:xpath("//h1"):text()

    if headline == "Your 2-Step Verification Code was not correct. Please try again:"    then
        return LoginFailed
    end
end

function InitializeSession2 (protocol, bankCode, step, credentials, interactive)
    connection = Connection()
    connection.useragent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36";

    if step == 1 then
        username = credentials[1]
        password = credentials[2]
        return loginStep1()
    elseif step == 2 then
        local twoFactorCode = credentials[1]
        return sendTwoFactorCode(twoFactorCode)
    end
end

function ListAccounts (knownAccounts)
    local coins = {
        name = "CoinTracking Coins",
        accountNumber = "CoinTracking Coins",
        owner = username,
        currency = "EUR",
        portfolio = true,
        type = AccountTypePortfolio
    }

    return {coins}
end

function RefreshAccount (account, since)
  local s = {}

  content = connection:get("https://cointracking.info/ajax/gains_sell.php?_=1")
  content = connection:get("https://cointracking.info/ajax/gains_summary.php?_=2")
  json = JSON(content)

  local assets = json:dictionary()["data"]

  for index, values in pairs(assets) do
      (function()
          local currencyName = HTML(values["cu"]):xpath("//a"):text()
          local shares = string.gsub(values["am"], "[^0-9.]", "")
          local sumInEur = string.gsub(values["cv"], "[^0-9.]", "")
          local purchasePriceInEur = string.gsub(values["cc"], "[^0-9.]", "")
          local pricePerCoinInEur = values["cp"]
          local changeRate24h = values["t1"]

          s[#s+1] = {
              name = currencyName,
              currency = nil,
              quantity = shares,
              amount = sumInEur,
              price = pricePerCoinInEur,
              purchasePrice = purchasePriceInEur,
              currencyOfOriginalAmount = "EUR"
          }
      end)()
  end

  return {securities=s}
end

function EndSession ()
end