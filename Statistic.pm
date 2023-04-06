package MyLibrary::Statistic;

use MyLibrary::DB;
use MyLibrary::Resource;
use MyLibrary::Patron;
use MyLibrary::Term;
use Carp;
use strict;

=head1 NAME

MyLibrary::Statistic


=head1 SYNOPSIS

	# use the module
	use MyLibrary::Statistic;
	
	# create a new statistic
	my $statistic = MyLibrary::Statistic->new;
	
	# give the statistic characteristics
	$statistic->statistic_query('MyLibrary');
	$statistic->statistic_date('2008-04-01');
	$statistic->statistic_type('QUERY');
	$statistic->statistic_src_ip('1.1.1.1');
	$statistic->statistic_referring_page('http://www.mylibraryinstance.edu/page/in/my/library');
	
	# associate the statistic with a resource and its associated terms
	$statistic->resource_id(801);
	
	# associate the statistic with a patron and the patron's associated terms
	$statistic->patron_id(802);
	
	# save the statistic; create a new record or update it
	$statistic->commit;
	
	# get the id of the current statistic object
	$id = $statistic->statistic_id;
	
	# create a new statistic object based on an id
	my $statistic = MyLibrary::Statistic->new(id => $id);
	
	# return the top n resource ids by statistic count
	my @stat_top_5;
	MyLibrary::Statistic->get_top(5, \@stat_top_5);
	
	# Or return the top 5 with their counts so you can sort them by count
	my %stat_top_10;
	MyLibrary::Statistic->get_top(10, \%stat_top_10);
	for my $key (sort {$stat_top_10{$b} <=> $stat_top_10{$a}} (keys(%stat_top_10)) {
		my $resource = MyLibrary::Resource->new(id => $key);
		my $count = $stat_top_10{$key};
		print "$resource->name() accessed $count times.\n";
	} 
	
	# return the term names associated to the statistic via the patron
	my @patron_terms = $statistic->get_patron_terms();
	
	# return the term names associated to the statistic via the resource
	my @resource_terms = $statistic->get_resource_terms();
	
	# display a statistic
	print '   Resource ID: ', $statistic->resource_id, "\n";
	print '         Query: ', $statistic->statistic_query, "\n";
	print '          Date: ', $statistic->statistic_date, "\n";
	print 'Statistic Type: ', $statistic->statistic_type, "\n";
	print '     Source IP: ', $statistic->statistic_src_ip, "\n";
	print 'Referring Page: ', $statistic->statistic_referring_page, "\n";
	my @patron_terms = $statistic->get_patron_terms();
	foreach my $patron_term (@patron_terms) {
		print '   Patron Term: ', $patron_term, "\n";
	}
	my @resource_terms = $statistic->get_resource_terms();
	foreach my $resource_term (@resource_terms) {
		print ' Resource Term: ', $resource_term, "\n";
	}

=head1 DESCRIPTION

The module provides a means of saving statistics for resources (or even non-resources) to the underlying MyLibrary database.

=head2 Caveats

A statistic can be related to a particular patron and/or resource.  In either case, additional data will be stored associating the statistic to the terms related to the patron and/or the resource. 
This data is for statistical purposes only and is therefore considered "historical."  For this reason, we have stored the term's name (which functions as an alternate primary key in the underlying database) rather than the terms's id. 
Therefore, if a term gets deleted, the term will still be accessible via it's name in the statistics even though it's id is no longer valid.


=head1 METHODS

This section describes the methods available in the package.


=head2 new()

Use this method to create a new statistic object. Called with no arguments, this method creates an empty object. Given an id, this method gets the statistic from the database associated accordingly.

	# create a new statistic object
	my $statistic = MyLibrary::Statistic->new;
  
	# create a statistic object based on a previously existing ID
	my $statistic = MyLibrary::Statistic->new(id => 3);


=head2 statistic_id()

This method returns an integer representing the database key of the currently created statistic object.

	# get id of current review object
	my $id = $statistic->statistic_id;

You cannot set the statistic_id attribute.


=head2 statistic_query()

This method gets and sets the text of the statistic for the current statistic object:

	# get the text of the current statistic object
	my $query = $statistic->statistic_query;
	
	# set the current statistic object's text
	$statistic->statistic('query');
	

=head2 statistic_date()

Set or get the date attribute of the statistic object with this method:

	# get the date attribute
	my $statistic_date = $statistic->statistic_date;
	
	# set the date
	$statistic->statistic_date('2003-10-31');

The date is expected to be in the format of YYYY-MM-DD.


=head2 resource_id()

Use this method to get and set what resource is being logged:

	# set the resource
	$statistic->resource_id('601');
	
	# get resource id
	my $resource_id = $statistic->resource_id;
	
If there are terms associated to this resource, they will be added to the statistic and can be accessed via $statistic->related_resource_terms();	


=head2 delete_resource_id()

Use this method to remove the statistic-resource association.  All related term associations will also be deleted.

	# remove resource association
	$statistic->delete_resource_id;

=head2 patron_id()

Use this method to get and set what patron is being logged:

	# set the patron
	$statistic->patron_id('601');
	
	# get patron id
	my $patron_id = $statistic->patron_id;
	
If there are terms associated to this patron, they will be added to the statistic and can be accessed via $statistic->related_resource_terms();	


=head2 delete_patron_id()

Use this method to remove the patron-statistic association.  All related term associations will also be removed.

	# remove patron association
	$statistic->delete_patron_id;
	

=head2 commit()

Use this method to save the statistic object's attributes to the underlying database. If the object's data has never been saved before, then this method will create a new record in the database. If you used the new and passed it an id option, then this method will update the underlying database.

This method will return true upon success.

	# save the current statistic object to the underlying database
	$statistic->commit;


=head2 delete()

This method simply deletes the current statistic object from the underlying database.

	# delete (drop) this statistic from the database
	$statistic->delete();
	
	
=head2 get_statistics();

Use this method to get statistics from the underlying database. It returns an array of statistic ids which match your criteria. 

With this method, you can get usage counts from the number of statistic_ids returned. 

	# get all statistics
	my @statistics = MyLibrary::Statistic->get_statistics;
	my $usage = @statistics;

	# get statistics related to a particular term
	my @statistics = MyLibrary::Statisitcs->get_statistics(term_name => $term);
	my $usage = @statistics;
	
	# get statistics related to a particular resource
	my @statistics = MyLibrary::Statistics->get_statistics(resource_id => $resource_id);
	my $usage = @statistics;
	
	# get statistics related to a particular patron
	my @statistics = MyLibrary::Statistics->get_statistics(patron_id => $patron_id);
	my $usage = @statistics;
	
	# get statistics by date
	my @statistics = MyLibrary::Statistics->get_statistics(start_date => '2008-05-01', end_date => '2008-05-31');
	my $usage = @statistics;
	
	# the options may be combined...
	# find statistics for a particular term for a given month
	my $start_date = '2008-07-01'
	my $end_date = '2008-07-31'
	my @statistics = MyLibrary::Statistics->get_statistics(term_name => $term, start_date => $start_date, end_date => $end_date); 	
	my $usage = @statistics;
	
	 	
 	print "$term used $usage times between $start_date and $end_date.\n";
 	

=head2 get_top()

Use this method to get the ids of the most frequently accessed resources.  There are two possibilities here:

=head3 Hash 

Use this method if you want to know the counts for each resource.  A hash will be returned with the resource ids as the key and the count as the value. 
	
	# get top 5 resources
	my %hash = ();
	MyLibrary::Statistic->get_top(5,\%hash);
	
	# get top 10 resources
	my %hash = ();
	MyLibrary::Statistic->get_top(10,\%hash); 

	# next sort the resources by usage in descending order 
	for my $key (sort {$hash{$b} <=> $hash{$a}} (keys(%hash)) {
		my $resource = MyLibrary::Resource->new(id => $key);
		my $count = $hash{$key};
		print "$resource->name() accessed $count times.\n";
	} 

Or if you prefer:

	# sort the resources by usage in ascending order
	for my $key (sort {$hash{$a} <=> $hash{$b}} (keys(%hash)) {
		my $resource = MyLibrary::Resource->new(id => $key);
		my $count = $hash{$key};
		print "$resource->name() accessed $count times.\n";
	} 
	

=head3 Array

	# get top 5 resources
	my @array;
	MyLibrary::Statistic->get_top(5, \@array);
	
	# get top 10 resources
	MyLibrary::Statistic->get_top(10, \@array); 
	



=head1 AUTHOR

John A. Scofield <jscofiel@nd.edu>


=head1 HISTORY

July 09, 2008 - Updated
May 08, 2008 - working draft; 


=cut


sub new {

	# declare local variables
	my ($class, %opts) = @_;
	my $self           = {};

	# check for an id
	if ($opts{id}) {
		
		# check for valid input, an integer
		if ($opts{id} =~ /\D/) {
		
			# output an error and return nothing
			croak "The id passed as input to the new method must be an integer: id = $opts{id} ";
			return;
			
		}
			
		# get a handle
		my $dbh = MyLibrary::DB->dbh();
		
		# find this record
		my $rv = $dbh->selectrow_hashref('SELECT * FROM statistics WHERE statistic_id = ?', undef, $opts{id});
		
		# check for a hash
		return unless ref($rv) eq 'HASH';

		# fill myself up with the fetched data
		$self = bless ($rv, $class);
			
	}
	
	# return the object
	return bless ($self, $class);
	
}


sub statistic_id {

	my $self = shift;
	return $self->{statistic_id};

}


sub statistic_query {

	# declare local variables
	my ($self, $statistic_query) = @_;
	
	# check for the existence of a name 
	if ($statistic_query) { $self->{statistic_query} = $statistic_query }
	
	# return it
	return $self->{statistic_query};
	
}

sub statistic_type {

	# declare local variables
	my ($self, $statistic_type) = @_;
	
	# check for the existence of a name 
	if ($statistic_type) { $self->{statistic_type} = $statistic_type }
	
	# return it
	return $self->{statistic_type};
	
}

sub statistic_src_ip {

	# declare local variables
	my ($self, $statistic_src_ip) = @_;
	
	# check for the existence of a name 
	if ($statistic_src_ip) { $self->{statistic_src_ip} = $statistic_src_ip }
	
	# return it
	return $self->{statistic_src_ip};
	
}

sub statistic_referring_page {

	# declare local variables
	my ($self, $statistic_referring_page) = @_;
	
	# check for the existence of a name 
	if ($statistic_referring_page) { $self->{statistic_referring_page} = $statistic_referring_page}
	
	# return it
	return $self->{statistic_referring_page};
	
}


sub statistic_date {

	# declare local variables
	my ($self, $date) = @_;
	
	# check for the existence of date
	if ($date) { $self->{statistic_date} = $date }
	
	# return it
	return $self->{statistic_date};
	
}


sub resource_id {

	# declare local variables
	my ($self, $resource_id) = @_;

	# check for the existence of resource id
	if ($resource_id) { 
		$self->{resource_id} = $resource_id;  
	
		# relate the terms from the resource to this statistic
		my $sql =  "SELECT	term_name 
					FROM	terms t, terms_resources x 
					WHERE	t.term_id = x.term_id AND
						  	resource_id = $resource_id
				    ORDER BY term_name asc";
		my $dbh = MyLibrary::DB->dbh();
		$self->{related_resource_terms} = $dbh->selectcol_arrayref($sql);

	}

	# return it
	return $self->{resource_id};
	
}

sub delete_resource_id {
	my $self = shift;
	undef $self->{resource_id};
	undef $self->{related_resource_terms};
	return 1;
}

sub patron_id {

	# declare local variables
	my ($self, $patron_id) = @_;

	# check for the existence of patron id
	if ($patron_id) { 
		$self->{patron_id} = $patron_id;  
	
		# relate the terms from this patron to the statistic
		my $sql =  "SELECT 	term_name 
					FROM 	terms t, patron_term x 
					WHERE 	t.term_id = x.term_id AND
							x.patron_id = $patron_id
					ORDER BY term_name asc";
		my $dbh = MyLibrary::DB->dbh();
		my $patron_terms = $dbh->selectcol_arrayref($sql);
		$self->{related_patron_terms} = $patron_terms;
	}

	# return it
	return $self->{patron_id};
	
}

sub delete_patron_id {
	my $self = shift;
	undef $self->{patron_id};
	undef $self->{related_patron_terms};
	return 1;
}

sub commit {

	# get myself, :-)
	my $self = shift;
	
	# get a database handle
	my $dbh = MyLibrary::DB->dbh();	
	
	# see if the object has an id
	if ($self->statistic_id) {
		my $return;
		
		# update the record in the statistics table with this id
		$return = $dbh->do(
			'UPDATE statistics 
			SET statistic_query = ?, statistic_date = ?, statistic_src_ip = ?,  statistic_referring_page = ?, statistic_type = ?, resource_id = ?, patron_id = ? 
			WHERE statistic_id = ?', undef, 
			$self->statistic_query, $self->statistic_date, $self->statistic_src_ip, $self->statistic_referring_page, $self->statistic_type, $self->resource_id, $self->patron_id, $self->statistic_id);
		if ($return > 1 || ! $return) { croak "Statistic creation in commit() failed. $return records were updated." }
		
		# update the patron terms associated with this record
		$return = $dbh->do(
			'DELETE FROM statistic_term WHERE statistic_id = ? AND source_type = ?', undef, $self->statistic_id, 'PATRON'
		);
		# create statistic=>term relations for patrons
		if ($self->related_patron_terms ) {
			my @patron_terms = $self->related_patron_terms();
			foreach my $term_name (@patron_terms) {
				my $return = $dbh->do(
					'INSERT INTO statistic_term (statistic_id,term_name,source_type) 
					VALUES (?, ?, ?)', undef,
					$self->statistic_id, $term_name, 'PATRON'					
				);
				if ($return > 1 || ! $return) { croak "Statistic->patron_term creation in commit() failed.  $return records were updated." }				
			}
		}
		
		
		# update the resource terms associated with this record
		$return = $dbh->do(
			'DELETE FROM statistic_term WHERE statistic_id = ? AND source_type = ?', undef, $self->statistic_id, 'RESOURCE'
		);
		# create statistic=>term relations for resources
		if ($self->related_resource_terms) {
			my @resource_terms = $self->related_resource_terms();
			foreach my $term_name (@resource_terms) {
				my $return = $dbh->do(
					'INSERT INTO statistic_term (statistic_id,term_name,source_type) 
					VALUES (?, ?, ?)', undef,
					$self->statistic_id, $term_name, 'RESOURCE'					
				);
				if ($return > 1 || ! $return) { croak "Statistic->resource_term creation in commit() failed.  $return records were updated." }				
			}
		}
		
	}
	
	else {
	
		# get a new sequence
		my $id = MyLibrary::DB->nextID();		

		# create a new record
		my $return;	
		$return = $dbh->do('INSERT INTO statistics (statistic_id, statistic_query, statistic_date, resource_id, patron_id, statistic_type, statistic_src_ip, statistic_referring_page) 
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)', undef, $id, $self->statistic_query, $self->statistic_date, $self->resource_id, $self->patron_id, $self->statistic_type, $self->statistic_src_ip, $self->statistic_referring_page);
		if ($return > 1 || ! $return) { croak 'Statistic commit() failed.'; }

		# create statistic=>term relations for patrons
		if ($self->related_patron_terms) { 
			my @patron_terms = $self->related_patron_terms();
			foreach my $term_name (@patron_terms) {
				my $return = $dbh->do(
					'INSERT INTO statistic_term (statistic_id,term_name,source_type) 
					VALUES (?, ?, ?)', undef,
					$id, $term_name, 'PATRON'					
				);
				if ($return > 1 || ! $return) { croak "Statistic->patron_term creation in commit() failed.  $return records were updated." }				
			}
		}
		
		# create statistic=>term relations for resources
		if ( $self->related_resource_terms ) {
			my @resource_terms = $self->related_resource_terms();
			foreach my $term_name (@resource_terms) {
				my $return = $dbh->do(
					'INSERT INTO statistic_term (statistic_id,term_name,source_type) 
					VALUES (?, ?, ?)', undef,
					$id, $term_name, 'RESOURCE'					
				);
				if ($return > 1 || ! $return) { croak "Statistic->resource_term creation in commit() failed.  $return records were updated." }				
			}
		}
	
			
		$self->{statistic_id} = $id;
			
	}
	
	# done
	return 1;
	
}


sub delete {

	# get myself
	my $self = shift;

	# check for id
	return 0 unless $self->{statistic_id};

	# delete this record
	my $dbh = MyLibrary::DB->dbh();
	my $rv = $dbh->do('DELETE FROM statistics WHERE statistic_id = ?', undef, $self->{statistic_id});
	if ($rv != 1) { croak ("Deleted $rv records. I'll bet this isn't what you wanted.") } 
	
	# done
	return 1;

}


sub get_statistics {

	# scope varibles
	my ($self,%opts) = @_;
	my ($sql,@bind_values);
	
	
	# check for options
	if (! %opts ) {
		# nothing specified, return all statistic ids
		$sql = "SELECT s.statistic_id FROM statistics s";		
	}
	else {
		#build some sql
		$sql = "SELECT s.statistic_id ";
		my $from = "FROM statistics s "; # this is the default from clause, only pulling from statistics table
		my $where;

		
		#check for which option - term, resource_id, patron_id, start_date, end_date
		if ($opts{term_name}) {
			# modify from clause to search terms as well
			$from = "FROM statistics s, statistic_term st ";
			$where = "s.statistic_id = st.statistic_id AND term_name = ? ";
			push (@bind_values,$opts{term_name});
		}
		if ($opts{resource_id}) {
			if ($where) { $where .= "AND " }
			$where .= "s.resource_id = ? ";
			push (@bind_values,$opts{resource_id});
		}
		if ($opts{patron_id}) {
			if ($where) { $where .= "AND " }
			$where .= "s.patron_id = ? ";
			push (@bind_values,$opts{patron_id});
		}
		if ($opts{start_date}) {
			if ($where) { $where .= "AND " }
			$where .= "s.statistic_date >= ? ";
			push (@bind_values,$opts{start_date});
		}
		if ($opts{end_date}) {
			if ($where) { $where .= "AND " }
			$where .= "s.statistic_date <= ? ";
			push (@bind_values,$opts{end_date});
		}
		$sql .= $from . "WHERE " . $where;
	}
	
	# create and execute a query
	my $dbh = MyLibrary::DB->dbh();
	my $rows = $dbh->selectcol_arrayref($sql, undef, @bind_values);

	
	# return the array	
	return @{ $rows };
	
}

sub get_top {

	# scope varibles
	my ($self, $num, $ref) = @_;
	
	# get database handle
	my $dbh = MyLibrary::DB->dbh();
	my $rv;
	
	# check for variable type
	if (ref($ref) eq "HASH") {
		my $sql =  'SELECT s.resource_id, count(*) as tot_hits  
					FROM statistics s, resources r 
					WHERE s.resource_id = r.resource_id 
					GROUP BY resource_id 
					ORDER BY count(*) DESC 
					LIMIT ' . $num;	
		# build the hash 
		%$ref = map { $_->[0], $_->[1] } @{$dbh->selectall_arrayref($sql)};
		
	}
	elsif (ref($ref) eq "ARRAY") {
		my $sql =  'SELECT s.resource_id  
					FROM statistics s, resources r 
					WHERE s.resource_id = r.resource_id 
					GROUP BY resource_id 
					ORDER BY count(*) DESC 
					LIMIT ' . $num;
		# build the array				
		map { push(@$ref,$_) } @{$dbh->selectcol_arrayref($sql)};
		
	} else {
		return 0;
	}
	
	# return the array	
	return 1;
	
}

sub related_patron_terms {

	# scope varibles
	my $self     = shift;
	my @rv = ();
	foreach my $term_name (@{$self->{related_patron_terms}}) {
		push(@rv,$term_name);
	}

	return @rv;
}

sub related_resource_terms {

	# scope varibles
	my $self = shift;
	my @rv = ();
	foreach my $term_name (@{ $self->{related_resource_terms}}) {
		push(@rv,$term_name);	
	}

	return @rv;
}


# return true, or else
1;
