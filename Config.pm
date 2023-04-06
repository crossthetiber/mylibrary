package MyLibrary::Config;

	our $DATA_SOURCE = '';
	our $USERNAME    = '';
	our $PASSWORD    = '';
	our $ML_KEY	 = '/usr/local/etc/mylibrary.key';
	our $SESSION_DIR = '/export/home/rfox/scripts/tmp';
	our $RELATIVE_PATH = '/tests';
	our $COOKIE_DOMAIN = '';
	our $HOME_URL = '';
	our $SCRIPTS_URL = '';
	our $SECURE_SCRIPTS_URL = '';
	our $NAME_OF_APPLICATION = '';
	our $JAVASCRIPT_URL = '';
	our $CSS_URL = '';
	our $IMAGE_URL = '';
	our $SSI_URL = '';
	our %SSI_PAGES = ('audience_html', 'nav_audiences.shtml', 'header_html', 'header.shtml', 'footer_html', 'footer.shtml', 'qsearches_html', 'quick_searches.shtml', 'branches_html', 'branches.shtml');
	our $INDEX_DIR = '/data/web_root/htdocs/main/indexes/';

1;
