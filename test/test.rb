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

end
