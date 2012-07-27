require "test/unit"

class TestCheckWebpage < Test::Unit::TestCase

  WEB_SERVER_URL='http://127.0.0.1:4567'

  # test minimal options
  def test_u
    assert( system( '../check_webpage.rb -u '+WEB_SERVER_URL ) )
  end

  # test verbose
  def test_u_vv
    assert( system( '../check_webpage.rb -vv >/dev/null -u '+WEB_SERVER_URL ) )
  end

  # test keyword
  def test_u_k
    assert( system( '../check_webpage.rb -k keyword -u '+WEB_SERVER_URL ) )
  end

  # test no inner downloads
  def test_u_n
    assert( system( '../check_webpage.rb -n -u '+WEB_SERVER_URL ) )
  end
 
  # test gzip (do not work with thin server alone :()
  def test_u_z
    assert( system( '../check_webpage.rb -z -u '+WEB_SERVER_URL ) )
  end

  # test bad url
  def test_bad_url
    assert_equal(false, system( '../check_webpage.rb -u http://4dsHfNYD4KRyktGH.com' ) )
  end

  # test bad keyword
  def test_bad_keyword
    assert_equal(false, system( '../check_webpage.rb -k 4dsHfNYD4KRyktGH -u '+WEB_SERVER_URL ) )
  end

  # test with subfolder (issue 11)
  def test_subfolder
     assert_match( /.*\, 3 files\,.*/, %x[../check_webpage.rb -u #{WEB_SERVER_URL}/subfolder/] )
  end

  # test cookies
  def test_cookie_exist
     assert( system( '../check_webpage.rb -C "gordon=freeman" -k freeman -u '+WEB_SERVER_URL+'/cookie' ) )
  end
  def test_cookie_not_found
     assert_equal(false, system( '../check_webpage.rb -C "gordon=potato" -k freeman -u '+WEB_SERVER_URL+'/cookie' ) )
  end

  #test timeout
  def test_timeout
    assert_equal(false, system( '../check_webpage.rb -c 1 -u '+WEB_SERVER_URL+'/wait3s' ) )
  end
end
