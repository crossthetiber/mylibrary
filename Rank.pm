package MyLibrary::Rank;

use MyLibrary::DB;
use Carp qw(croak);
use strict;

=head1 NAME

MyLibrary::Rank

=head1 SYNOPSIS

	# require the necessary module
	use MyLibrary::Rank;

	# create an undefined Rank object
	my $rank = MyLibrary::Rank->new();
	
	# construct a specific rank object
	my $rank = MyLibrary::Rank->(id => $rank_id);
	
	# designate the resource for the rank
	my $rank_resource_id = $rank->resource($resource_id);
	
	# get or set the rank value
	my $rank_number = $rank->rank($number);
	
	# get or set the rank type
	my $rank_type = $rank->rank_type(9);

	# get rank id
	my $rank_id = $rank->rank_id();
	
	# add rank criteria
	$rank->add_criteria(id => $term_id); (for type single_term)
	$rank->add_criteria(id_list => [$term_id, $term_id]); (for type combined_term)
	$rank->add_criteria(id => $facet_id); (for type facet)
	
	# remove rank criteria
	$rank->remove_criteria(id => $term_id); (for type sing_term)
	$rank->remove_criteria(id => $facet_id); (for type facet)
	$rank->remove_criteria(ids => [$term_id, $term_id]); (for combined_term)
	
	# list rank criteria
	my $criteria = $rank->list_criteria();
	
	# set rank value without full commit
	$rank->quick_value(10);
	
	# commit rank information
	$rank->commit();
	
	# cleanup rank data
	MyLibrary::Rank->cleanup(type => 'resource_delete', id => $resource_id);
	MyLibrary::Rank->cleanup(type => 'resource_term_change', id => $resource_id, term_id => $term_id);
	MyLibrary::Rank->cleanup(type => 'term_facet_change', id => $term_id);
	MyLibrary::Rank->cleanup(type => 'term_delete', id => $term_id);
	MyLibrary::Rank->cleanup(type => 'facet_delete', id => $facet_id);
	
	# get all resources by rank type and criteria
	my $ranked_resources = MyLibrary::Rank->ranked_list(type => 'facet', id => $facet_id);
	my $ranked_resources = MyLibrary::Rank->ranked_list(type => 'single_term', id => $term_id);
	my $ranked_resources = MyLibrary::Rank->ranked_list(type => 'combined_term', ids => [$term_id, $term_id]);
	
	# repopulate the rank data table
	MyLibrary::Rank->populate_rank_data();
	
	# get a hash of rank values for a resource
	my %resource_rankings = MyLibrary::Rank->rank_by_resource($resource_id);
	
	# delete ranking for a resource
	$rank->delete();
	
=head1 DESCRIPTION

Use this module to get and set resource rank information to a MyLibrary database. Ranks are based on a set of criteria. Each rank is a numerical value. That numerical value is then associated with a set of criteria. The criteria can include multiple MyLibrary term designations in order to create very specific rankings. By giving a resource a ranking, it automatically becomes a recommended resource, ranked according to the criteria specified. Specific kinds of rankings should be created based on the kind of criteria input. Currently, only three kinds of raking types are allowed: single_term, combined_term and facet. Each type determines the criteria that can be designated for the rank.

=head1 METHODS

=cut
	
=head2 new()

This method creates a new rank object. Called with no input, this constructor will return a new, empty rank object:

	# create empty rank object
	my $rank = MyLibrary::Rank->new();

The constructor can also be called using a known rank id:

	# create a rank object using a known rank id
	my $rank = MyLibrary::Rank->new(id => $rank_id);

=cut

sub new {

	# declare local variables
	my ($class, %opts) = @_;
	my $self = {};
	
	# check for an id
	if ($opts{id}) {
	
		my $dbh = MyLibrary::DB->dbh();
		my $rv = $dbh->selectrow_hashref('SELECT * FROM rank WHERE rank_id = ?', undef, $opts{id});
		if (ref($rv) eq "HASH") { 
			$self = $rv;
		} else { 
			return; 
		}
		# this will return an arrayref to a hashref for each row returned from the query
		my $criteria_arry_ref = $dbh->selectall_arrayref('SELECT * FROM rank_criteria WHERE rank_id = ?', { Slice => {} }, $opts{id});
		$self->{criteria} = \@{$criteria_arry_ref};
	} else {
		# default
		my %default = ();
		$self = \%default;
		my @empty_criteria = ();
		$self->{criteria} = \@empty_criteria;
		
	}
	
	# return the object
	return bless $self, $class;
	
}

=head2 populate_rank_data()

It is necessary to run this method at least once before calling ranked_list(). This is a class method that will populate a table with data taken from the rank and rank_criteria tables. The rank_data table is necessary in order for ranked_list() to operate efficiently.

	# populate the rank_data table
	MyLibrary::Rank->populate_rank_data()
	
This method does not take any parameters, and will return a status code based on the success or failure of the operation.

=cut

sub populate_rank_data {
	
	# return values
	# 1 - success
	# 2 - failure
	
	my $class = shift;
	my $return_val = 1;
	
	my $dbh = MyLibrary::DB->dbh();
	$dbh->{RaiseError} = 1;
	my $ranks = $dbh->selectall_hashref('SELECT * FROM rank', 'rank_id');
	my %rank_object_data = ();
	foreach my $rank_id (keys %{$ranks}) {
		if ($ranks->{$rank_id}->{rank_type} eq 'facet') {
			my %rank_info = ();
			$rank_info{rank_id} = $rank_id;
			$rank_info{resource_id} = $ranks->{$rank_id}->{resource_id};
			$rank_info{rank} = $ranks->{$rank_id}->{rank};
			$rank_info{rank_type} = $ranks->{$rank_id}->{rank_type};
			my $id_values = $dbh->selectcol_arrayref('SELECT facet_id FROM rank_criteria WHERE rank_id = ?', undef, $rank_id);
			$rank_info{id_values} = $id_values->[0];
			$rank_object_data{$rank_id} = \%rank_info;
		} elsif ($ranks->{$rank_id}->{rank_type} eq 'combined_term') {
			my %rank_info = ();
			$rank_info{rank_id} = $rank_id;
			$rank_info{resource_id} = $ranks->{$rank_id}->{resource_id};
			$rank_info{rank} = $ranks->{$rank_id}->{rank};
			$rank_info{rank_type} = $ranks->{$rank_id}->{rank_type};
			my $id_values = $dbh->selectcol_arrayref('SELECT term_id FROM rank_criteria WHERE rank_id = ?', undef, $rank_id);
			my $id_val_string;
			map { $id_val_string .= $_} (reverse sort {$a<=>$b} @{$id_values});
			$rank_info{id_values} = $id_val_string;
			$rank_object_data{$rank_id} = \%rank_info;
		} elsif ($ranks->{$rank_id}->{rank_type} eq 'single_term') {
			my %rank_info = ();
			$rank_info{rank_id} = $rank_id;
			$rank_info{resource_id} = $ranks->{$rank_id}->{resource_id};
			$rank_info{rank} = $ranks->{$rank_id}->{rank};
			$rank_info{rank_type} = $ranks->{$rank_id}->{rank_type};
			my $id_values = $dbh->selectcol_arrayref('SELECT term_id FROM rank_criteria WHERE rank_id = ?', undef, $rank_id);
			$rank_info{id_values} = $id_values->[0];
			$rank_object_data{$rank_id} = \%rank_info;
		}
	}
	
	eval {
		$dbh->begin_work();
		$dbh->do('DELETE FROM rank_data');
		foreach my $rank_id (keys %rank_object_data) {
			$dbh->do('INSERT INTO rank_data (rank_id, resource_id, rank, id_values, rank_type) VALUES (?, ?, ?, ?, ?)', undef, $rank_id, $rank_object_data{$rank_id}->{resource_id}, $rank_object_data{$rank_id}->{rank}, $rank_object_data{$rank_id}->{id_values}, $rank_object_data{$rank_id}->{rank_type});
		}
		$dbh->commit();
	};
	
	if ($@) {
		$return_val = 2;
		# now rollback to undo the incomplete changes
		# but do it in an eval{} as it may also fail
		eval { $dbh->rollback() };
	}
	
	return $return_val;
	
}

=head2 rank_id()

This object method is used to retrieve the rank id of the current rank object. This method cannot be used to set the rank id.

	# get rank id
	my $rank_id = $rank->rank_id();
	
=cut

sub rank_id {

	my $self = shift;
	unless ($self->{rank_id}) { croak "Rank id not found. Perhaps commit() needs to be called first."}
	return $self->{rank_id};

}

=head2 rank()

This is an attribute method which allows you to either get or set the rank attribute of a rank object. A rank value must be an integer.

	# get the rank
	my $rank_value = $rank->rank();

	# set the rank
	$rank->rank(10);
	
=cut

sub rank {

	# declare local variables
	my ($self, $rank_value) = @_;
	
	# check for the existance of rank value
	if ($rank_value && $rank_value !~ /^\d+$/) { croak "Only integers can be submitted for a rank value." }
	if ($rank_value && $rank_value =~ /^\d+$/) { $self->{rank} = $rank_value }
	
	# return the name
	return $self->{rank};
	
}

=head2 quick_value()

This method is a work around for performance issues. Instead of needing to do a full commit on a rank object, the developer can quickly change the rank value for a particular rank with this method.

The downside to this method is that it does not protect the data integrity. Just call the method, and the value for that rank will be changed to the parameter submitted.

	# set the rank value
	$rank->quick_value(10);

=cut

sub quick_value {
	
	my $self = shift;
	my $quick_value = shift;
	
	unless ($quick_value =~ /\d+/) { croak "Only numeric values can be submitted to quick_value() method." }
	
	unless ($self->{rank_id}) {croak "A valid rank id was not found for rank."}
	
	my $dbh = MyLibrary::DB->dbh();
	my $return = $dbh->do('UPDATE rank SET rank = ? WHERE rank_id = ?', undef, $quick_value, $self->{rank_id});
	if ($return > 1 || ! $return) { croak "Rank update in commit() failed. $return records were updated." }
	
	return 1;
}

=head2 resource()

This is an attribute method which allows you to either get or set the resource attribute of a rank object. A resource value must be an integer, and must correspond to an existing resource object.

	# get the resource id value
	my $rank_resource_id = $rank->resource();

	# set the resource id value
	$rank->resource(15);
	
=cut

sub resource {

	# declare local variables
	my ($self, $resource_id) = @_;
	
	# check for the existance of resource_id
	if ($resource_id && $resource_id =~ /^\d+$/) { 
		
		my $dbh = MyLibrary::DB->dbh();
		my $resource_ids = $dbh->selectcol_arrayref('SELECT resource_id FROM resources WHERE resource_id = ?', undef, $resource_id);
		if (scalar(@{$resource_ids}) == 1) {
			$self->{resource_id} = $resource_id;
		} else { croak "Either more than one resource id or no resource ids were found for resource ranking." }
		 
	}
	
	if ($resource_id && $resource_id !~ /^\d+$/) { croak "Only integers can be submitted for a ranked resource id." }
	
	# return the resource_id
	return $self->{resource_id};

}

=head2 add_criteria() 

This method will add rank criteria for a particular ranking. The ids submitted (facet or term) must exist in the database, or an error will result. Also, the rank_type for this rank must be designated prior to calling this method. It will also check to make sure that the rank has been committed to the database. The return code will indicate whether the operation was successful or if unsuccessful and the reason for failure (based on return code number).

	# add the rank criteria
	$rank->add_criteria(id => $term_id); (for single_term type)
	$rank->add_criteria(ids => [$term_id, $term_id]); (for combined_term type)
	$rank->add_criteria(id => $facet_id); (for facet type)
	
The return codes are: 1 = success, 2 = single_term duplcate ignored, 3 = single term other criteria exists, 4 = facet duplicate ignored, 5 = facet other criteria exists, 6 = combined term duplicate fourd, 7 = at least one term id submitted not associated with resource for combined type, 8 = both duplicate found and unassociated term id found for combined type, 9 = resource not related to facet, 10 = resource not related to term.

It is extremely important that error checking occur when this method is run. The developer should consider a series of calls to this method as a transaction. If any of the calls fail, the transaction should not complete (a call to commit() should not be made).
	
=cut

sub add_criteria {
	
	# For this method, the return values are as follows:
	# 1 = successful add
	# 2 = single term duplicate criteria ignored
	# 3 = single term other criteria already exists for rank
	# 4 = facet duplicate criteria ignored
	# 5 = facet other criteria already exists for rank
	# 6 = combined term at least one criteria already exists from term list
	# 7 = at least one term id submitted not associated with resource
	# 8 = both duplicate criteria and non associated term id in combined_term criteria
	# 9 = resource not related to facet
	# 10 = resource not related to term
	my $return_code;
	
	my $self = shift;
	my %opts = @_;
	
	unless ($self->resource() && $self->resource() =~ /^\d+/) { croak "Cannot add criteria for rank not associated with valid resource id in add_criteria()."}
	# create resource object for testing
	my $rank_resource = MyLibrary::Resource->new(id => $self->resource());
	my @resource_terms = $rank_resource->related_terms();
	my %facets_for_terms = ();
	map { $facets_for_terms{$_} = MyLibrary::Term->new(id => $_)->facet_id()} @resource_terms;
	my %facet_list = ();
	map {$facet_list{$_} = 1} values %facets_for_terms;
	
	# current criteria
	my @current_criteria = @{$self->{criteria}};
	
	if ($self->rank_type() eq 'facet' || $self->rank_type() eq 'single_term') {
		unless ($opts{id} =~ /^\d+$/) { croak "Either no id parameter was submitted or a non-integer parameter was submitted." }
		# facet criteria
		if ($self->rank_type() eq 'facet') {
			my $dbh = MyLibrary::DB->dbh();
			# test for facet existence
			my $facet_ids = $dbh->selectcol_arrayref('SELECT facet_id FROM facets WHERE facet_id = ?', undef, $opts{id});
			unless (scalar(@{$facet_ids}) == 1) { croak "Submitted facet id not found or duplicate found in rank_type()."}
			unless ($facet_list{$opts{id}}) { $return_code = 9 }
			my $found_criteria = 0;
			if (scalar(@current_criteria) >= 1) {
				foreach my $criteria (@current_criteria) {
					if ($criteria->{facet_id} == $opts{id} && $criteria->{term_id} < 1) {
						$found_criteria = 1;
					}
				}
			}
			if ($found_criteria) {
				$return_code = 4;
			} else {
				if (scalar(@current_criteria) >= 1) {
					$return_code = 5;
				} else {
					unless ($return_code == 9) {
						my %new_criteria = ();
						$new_criteria{facet_id} = $opts{id};
						$new_criteria{term_id} = 0;
						push(@current_criteria, \%new_criteria);
						$self->{criteria} = \@current_criteria;
						# success
						$return_code = 1;
					}
				}
			}
		}
		# single_term criteria
		if ($self->rank_type() eq 'single_term') {
			my $dbh = MyLibrary::DB->dbh();
			# test for term existence
			my $term_ids = $dbh->selectcol_arrayref('SELECT term_id FROM terms WHERE term_id = ?', undef, $opts{id});
			unless (scalar(@{$term_ids}) == 1) { croak "Submitted term id not found in database or duplicate found in rank_type()."}
			unless ($facets_for_terms{$opts{id}}) { $return_code = 10 }
			my $found_criteria = 0;
			if (scalar(@current_criteria) >= 1) {
				foreach my $criteria (@current_criteria) {
					if ($criteria->{facet_id} == $facets_for_terms{$opts{id}} && $criteria->{term_id} == $opts{id}) {
						$found_criteria = 1;
					}
				}
			}
			if ($found_criteria) { 
				$return_code = 2;
			} else {
				if (scalar(@current_criteria) >= 1) {
					$return_code = 3;
				} else {
					unless ($return_code == 10) {
						my %new_criteria = ();
						$new_criteria{facet_id} = $facets_for_terms{$opts{id}};
						$new_criteria{term_id} = $opts{id};
						push(@current_criteria, \%new_criteria);
						$self->{criteria} = \@current_criteria;
						# success
						$return_code = 1;
					}
				}
			}
		}
	}
	
	# combined_term criteria
	if ($self->rank_type() eq 'combined_term') {
		unless ($opts{ids}) { croak "An array of ids must be submitted with the ids parameter if the rank type is combined_term" }
		unless (scalar(@{$opts{ids}}) >= 1) { croak "At least one term id must be submitted in the ids parameter with type combined_term" }
		my $dbh = MyLibrary::DB->dbh();
		my $duplicate_flag = 0;
		my $not_associated_flag = 0;
		foreach my $ids_value (@{$opts{ids}}) {
			if ($ids_value !~ /^\d+$/) { croak "A non integer was submitted via the ids parameter in rank_type()." }
			my $term_ids = $dbh->selectcol_arrayref('SELECT term_id FROM terms WHERE term_id = ?', undef, $ids_value);
			unless (scalar(@{$term_ids}) == 1) { croak "Submitted term id not found or duplicate found in rank_type() with type combined_term." }
			unless ($facets_for_terms{$ids_value}) { $not_associated_flag = 1; next; }
			# check to see if duplicate criteria already exists for this rank, and if so, ignore it
			my $found_criteria = 0;
			if (scalar(@current_criteria) >= 1) {
				foreach my $criteria (@current_criteria) {
					if ($criteria->{facet_id} == $facets_for_terms{$ids_value} && $criteria->{term_id} == $ids_value) {
						$found_criteria = 1;
					}
				}
			}
			if ($found_criteria) {
				$duplicate_flag = 1;	
			} else {
				my %new_criteria = ();
				$new_criteria{facet_id} = $facets_for_terms{$ids_value};
				$new_criteria{term_id} = $ids_value;
				push(@current_criteria, \%new_criteria);
				$self->{criteria} = \@current_criteria;
				# success
				$return_code = 1;
			}
		}
		
		if ($duplicate_flag) {
			$return_code = 6;
		}
		if ($not_associated_flag) {
			$return_code = 7;
		}
		if ($duplicate_flag && $not_associated_flag) {
			$return_code = 8;
		}	
	}
	
	# return
	return $return_code;
}

=head2 remove_criteria() 

This method will remove rank criteria for a particular ranking. Specific criteria for the rank object will be removed based on submitted parameters. The return code will indicate whether the operation was successful or if unsuccessful.

	# add the rank criteria
	$rank->remove_criteria(id => $term_id); (for all types)
	
The id parameter is required. This method also requires that a rank type be assigned to the rank object.

A return code of 1 indicates success and a return code of 2 indicates that the criteria was not found.

=cut

sub remove_criteria {
	
	# For this method, the return values are as follows:
	# 1 = successful removal
	# 2 = criteria not found
	
	my $self = shift;
	my %opts = @_;
	my @current_criteria = @{$self->{criteria}};
	
	unless ($self->rank_type()) { croak "No rank type found. Please assign before calling remove_criteria()."}
	
	unless ($opts{id} && $opts{id} =~ /^\d+$/) { croak "The id parameter not submitted but required in remove_criteria()."}
	
	my $facet_id;
	if ($self->rank_type() eq 'single_term' || $self->rank_type() eq 'combined_term') {
		$facet_id = MyLibrary::Term->new(id => $opts{id})->facet_id();
	} elsif ($self->rank_type() eq 'facet') {
		$facet_id = $opts{id};
	}

	my $found_criteria = 0;
	if (scalar(@current_criteria) >= 1) {
		foreach my $criteria (@current_criteria) {
			if ($self->rank_type() eq 'single_term' || $self->rank_type() eq 'combined_term') {
				if ($criteria->{facet_id} == $facet_id && $criteria->{term_id} == $opts{id}) {
					$found_criteria = 1;
				}
			} elsif ($self->rank_type() eq 'facet') {
				if ($criteria->{facet_id} == $opts{id} && $criteria->{term_id} < 1) {
					$found_criteria = 1;	
				}
			}
		}
	}
	
	my @new_criteria = ();
	unless ($found_criteria) {
		return 2;
	} else {
		foreach my $criteria (@current_criteria) {
			if ($self->rank_type() eq 'single_term' || $self->rank_type() eq 'combined_term') {
				unless ($criteria->{facet_id} == $facet_id && $criteria->{term_id} == $opts{id}) {
					my %new_criteria = ();
					$new_criteria{facet_id} = $criteria->{facet_id};
					$new_criteria{term_id} = $criteria->{term_id};
					push(@new_criteria, \%new_criteria);
				}
			} elsif ($self->rank_type() eq 'facet') {
				unless ($criteria->{facet_id} == $facet_id && $criteria->{term_id} < 1) {
					my %new_criteria = ();
					$new_criteria{facet_id} = $criteria->{facet_id};
					$new_criteria{term_id} = $criteria->{term_id};
					push(@new_criteria, \%new_criteria);	
				}
			}
		}
	}
	
	# success
	$self->{criteria} = \@new_criteria;
	return 1;
}

=head2 cleanup()

There are occasions when the affiliations between facets, terms and resources change. This necessitates the deletion of associated ranking information because there is no clean way to migrate rank information between one affiliation and another. When terms are deleted, or resources are removed from term affiliations, the ranks need to be eliminated. This method performs that function.

This class method requires at least two parameters. The first is a parameter indicating what kind of change is taking place. The second is the id for the MyLibrary object that is being modified. If the change involves a resource changing affiliation with a term, then an extra parameter is required for the term id. The method will take this data and use it to remove the ranking information from the database.

	# resource deleted
	MyLibrary::Rank->cleanup(type => 'resource_delete', id => $resource_id);
	
	# resource removed from term affiliation
	MyLibrary::Rank->cleanup(type => 'resource_term_change', id => $resource_id, term_id => $term_id);
	
	# term changes facet affiliation
	MyLibrary::Rank->cleanup(type => 'term_facet_change', id => $term_id);
	
	# term deleted
	MyLibrary::Rank->cleanup(type => 'term_delete', id => $term_id);
	
	# facet deleted
	MyLibrary::Rank->cleanup(type => 'facet_delete', id => $facet_id);
	
The method has several return codes. A return code of 2 indicates that at least one rank could not be deleted.
	
=cut

sub cleanup {
	
	# For this method, the return values are as follows:
	# 1 = operation successful
	# 2 = a rank could not be deleted 
	
	my $class = shift;
	unless ($class eq 'MyLibrary::Rank') { croak "Method must be called as a class method in cleanup()." }
	my %opts = @_;
	
	my %type_opts = ('resource_delete' => 1, 'resource_term_change' => 1, 'term_facet_change' => 1, 'term_delete' => 1, 'facet_delete' => 1);
	
	unless ($opts{type} && $type_opts{$opts{type}}) { croak "Either incorrect type parameter submitted or no type parameter submitted in cleanup()." }
	unless ($opts{id} && $opts{id} =~ /^\d+$/) { croak "Id parameter not submitted or id parameter not an integer in cleanup()."}
	
	if ($opts{type} eq 'resource_term_change') {
		unless ($opts{term_id} && $opts{term_id} =~ /^\d+$/) { croak "Either no term_id or incorrect term_id parameter submitted in cleanup()."}
	}
	
	my $return_code = 1;
	my $dbh = MyLibrary::DB->dbh();
	my $rank_ids;
	if ($opts{type} eq 'resource_delete') {
		
		$rank_ids = $dbh->selectcol_arrayref('SELECT rank_id FROM rank WHERE resource_id = ?', undef, $opts{id});

	} elsif ($opts{type} eq 'resource_term_change') {
		
		$rank_ids = $dbh->selectcol_arrayref('SELECT r.rank_id 
												 FROM  rank r INNER JOIN rank_criteria rc ON r.rank_id = rc.rank_id
												 WHERE r.resource_id = ?
												 AND rc.term_id = ?', undef, $opts{id}, $opts{term_id});
		
	} elsif ($opts{type} eq 'term_facet_change' || $opts{type} eq 'term_delete') {
		
		$rank_ids = $dbh->selectcol_arrayref('SELECT rank_id FROM rank_criteria WHERE term_id = ?', undef, $opts{id});

	} elsif ($opts{type} eq 'facet_delete') {
		
		$rank_ids = $dbh->selectcol_arrayref('SELECT rank_id FROM rank_criteria WHERE facet_id = ?', undef, $opts{id});

	}
	
	if (scalar(@{$rank_ids}) >= 1) {
		foreach my $rank_id (@{$rank_ids}) {
			my $rank = $class->new(id => $rank_id);
			my $return = $rank->delete();
			unless ($return == 1) {$return_code = 2}
		}
	}
	
	return $return_code;
}

=head2 rank_by_resource()

This class method will retrieve a list of rank ids based on the submitted resource id. It will return a hash of values keyed by the type of ranking associated with the resource.

	# get hash of rankings for a resource
	my %resource_ranks = MyLibrary::Rank->rank_by_resource($resource_id);
	
If the resource cannot be found in the database, value of 2 will be returned (not a hash); If no rankings are found, the has will be empty (null).

The key of the hash will be the ranking type. The values will be references to arrays containing the separate rank ids for each category.

=cut

sub rank_by_resource {
	
	my $class = shift;
	my $resource_id = shift;
	
	unless ($resource_id && $resource_id =~ /^\d+/) { croak "No valid resource id was submitted in rank_by_resource()." }
	unless (wantarray()) { croak "This subroutine will only return a hash array, not a scalar value" }
	
	my $resource = MyLibrary::Resource->new(id => $resource_id);
	if ($resource) {
		unless ($resource->isa('MyLibrary::Resource')) { return 2 }
	} else {
		return 2;
	}
	
	my $dbh = MyLibrary::DB->dbh();
	my $rank_ids = $dbh->selectcol_arrayref('SELECT rank_id FROM rank WHERE resource_id = ?', undef, $resource->id());
	if (scalar(@{$rank_ids}) < 1) { return }
	
	my %return_hash = ();
	foreach my $rank_id (@{$rank_ids}) {
		
		my $rank = $class->new(id => $rank_id);
		if ($return_hash{$rank->rank_type()}) {
			my @ids = @{$return_hash{$rank->rank_type()}};
			push(@ids, $rank_id);
			$return_hash{$rank->rank_type()} = \@ids;
		} else {
			my @new_ids = ();
			push(@new_ids, $rank_id);
			$return_hash{$rank->rank_type()} = \@new_ids;
		}
	}
	
	return %return_hash;
	
}

=head2 list_criteria()

This object method will return a reference to an array containing each criteria for the ranking. The values of the array will be references to a hash containing a value for the facet id and the term id for that criteria.

	# return an array reference of criteria for rank
	my $rank_criteria = $rank->list_criteria();
	
If no criteria has been assigned to this rank, the value will be null.

=cut

sub list_criteria {
	
	my $self = shift;
	
	return $self->{criteria};
	
}

=head2 ranked_list()

This class method allows the retrieval of a ranked list of resources for a rank. The method will return a reference to a hash of values, with the key being the ranking for the resources in the list, and the value being an anonymous hash with the following values: the resource_id, the rank_id, the rank, and a count value which can be ignored. There are several error codes which can be returned depending on the criteria supplied as parameters. They will only be returned if there is a problem, otherwise, the ranked list hash reference gets returned. 

	# get ranked list of resources in the form of a hash reference
	my $resource_ids = MyLibrary::Rank->ranked_list(type => 'facet', id => $facet_id);
	my $resource_ids = MyLibrary::Rank->ranked_list(type => 'single_term', id => $term_id);
	my $resource_ids = MyLibrary::Rank->ranked_list(type => 'combined_term', ids => [$term_id, $term_id]);

=cut

sub ranked_list {
	
	# For this method, the return values are as follows:
	# 3 = no rankings found for submitted criteria
	
	my $return_code;
	
	my $class = shift;
	my %opts = @_;
	
	my $returned_hash;
	
	unless ($opts{type} && ($opts{type} eq 'single_term' || $opts{type} eq 'facet' || $opts{type} eq 'combined_term')) {
		croak "Either no type parameter was submitted or incorrect type parameter was submitted in ranked_list().";
	}
	
	my $dbh = MyLibrary::DB->dbh();
	if ($opts{type} eq 'single_term') {
		
		# make sure the id param was submitted
		unless ($opts{id} && $opts{id} =~ /^\d+$/) { croak "Either no id parameter was submitted or the id param value was not an integer." }
		
		# first, check to make sure that the term exists in the database
		my $term_ids = $dbh->selectcol_arrayref('SELECT term_id FROM terms WHERE term_id = ?', undef, $opts{id});
		unless (scalar(@{$term_ids}) == 1) { croak "Submitted term id not found in database or duplicate found in ranked_list()."}
		
		# then, find the ranked resources for this term. if no resources
		# are ranked for this term, return a special return code
		my $key_field = 'rank';
		my $statement = "SELECT rank, resource_id, rank_id FROM rank_data where id_values = ? ORDER BY rank";
		$returned_hash = $dbh->selectall_hashref($statement, $key_field, undef, $opts{id});
		if (scalar(keys %{$returned_hash}) < 1) { return 3 }
		
	} elsif ($opts{type} eq 'facet') {
		
		# make sure the id param was submitted
		unless ($opts{id} && $opts{id} =~ /^\d+$/) { croak "Either no id parameter was submitted or the id param value was not an integer." }
		
		# first, check to make sure that the facet exists in the database
		my $term_ids = $dbh->selectcol_arrayref('SELECT facet_id FROM facets WHERE facet_id = ?', undef, $opts{id});
		unless (scalar(@{$term_ids}) == 1) { croak "Submitted facet id not found in database or duplicate found in ranked_list()."}
		
		# then, find the ranked resources for this facet. if no resources
		# are ranked for this facet, return a special return code
		my $key_field = 'rank';
		my $statement = "SELECT rank, resource_id, rank_id FROM rank_data where id_values = ? ORDER BY rank";
		$returned_hash = $dbh->selectall_hashref($statement, $key_field, undef, $opts{id});
		if (scalar(keys %{$returned_hash}) < 1) { return 3 }
		
	} elsif ($opts{type} eq 'combined_term') {
		
		# make sure the id param was submitted
		unless ($opts{ids}) { croak "The ids parameter was not submitted in ranked_list()." }
		unless (scalar(@{$opts{ids}}) >= 1) { croak "No term ids found in ids parameter." }
		# first, check to make sure that the terms exist in the database
		foreach my $term_id (@{$opts{ids}}) {
			my $term_ids = $dbh->selectcol_arrayref('SELECT term_id FROM terms WHERE term_id = ?', undef, $term_id);
			unless (scalar(@{$term_ids}) == 1) { return 3 }
		}
		
		# then, find the ranked resources for this term. if no resources
		# are ranked for this term, return a special return code
		my @submitted_ids = @{$opts{ids}};
		my $term_list;
		my $sorted_ids;
		map { $sorted_ids .= $_} reverse sort {$a <=> $b} @submitted_ids;
		my $key_field = 'rank';
		my $statement = "SELECT rank, resource_id, rank_id FROM rank_data where id_values = ? ORDER BY rank";
		$returned_hash = $dbh->selectall_hashref($statement, $key_field, undef, $sorted_ids);
		if (scalar(keys %{$returned_hash}) < 1) { return 3 }
		
	}
	
	return $returned_hash;
}

=head2 ranked_list_current()

This class method allows the retrieval of a ranked list of resources for a rank, based on the rank_criteria table. The method will return a reference to a hash of values, with the key being the ranking for the resources in the list, and the value being an anonymous hash with the following values: the resource_id, the rank_id, the rank, and a count value which can be ignored. There are several error codes which can be returned depending on the criteria supplied as parameters. They will only be returned if there is a problem, otherwise, the ranked list hash reference gets returned. 

	# get ranked list of resources in the form of a hash reference
	my $resource_ids = MyLibrary::Rank->ranked_list(type => 'facet', id => $facet_id);
	my $resource_ids = MyLibrary::Rank->ranked_list(type => 'single_term', id => $term_id);
	my $resource_ids = MyLibrary::Rank->ranked_list(type => 'combined_term', ids => [$term_id, $term_id]);

=cut

sub ranked_list_current {
	
	# For this method, the return values are as follows:
	# 2 = single term ranked list not found
	# 3 = no rankings found for submitted criteria
	
	my $return_code;
	
	my $class = shift;
	my %opts = @_;
	
	my $returned_hash;
	
	unless ($opts{type} && ($opts{type} eq 'single_term' || $opts{type} eq 'facet' || $opts{type} eq 'combined_term')) {
		croak "Either no type parameter was submitted or incorrect type parameter was submitted in ranked_list().";
	}
	
	my $dbh = MyLibrary::DB->dbh();
	if ($opts{type} eq 'single_term') {
		
		# make sure the id param was submitted
		unless ($opts{id} && $opts{id} =~ /^\d+$/) { croak "Either no id parameter was submitted or the id param value was not an integer." }
		
		# first, check to make sure that the term exists in the database
		my $term_ids = $dbh->selectcol_arrayref('SELECT term_id FROM terms WHERE term_id = ?', undef, $opts{id});
		unless (scalar(@{$term_ids}) == 1) { croak "Submitted term id not found in database or duplicate found in ranked_list()."}
		
		# then, find the ranked resources for this term. if no resources
		# are ranked for this term, return a special return code
		my $key_field = 'rank';
		my $statement = '
		SELECT ro.resource_id, ro.rank, rco.rank_id, count(rco.rank_id) AS count_ignore
		FROM rank_criteria rco INNER JOIN rank ro ON rco.rank_id = ro.rank_id
		WHERE rco.rank_id IN (
			SELECT r.rank_id
			FROM rank_criteria rc INNER JOIN rank r ON rc.rank_id = r.rank_id
			WHERE rc.term_id in (?) 
			AND r.rank_type = \'single_term\'
			GROUP BY r.rank_id
			HAVING COUNT(r.rank_id) = ?)
		GROUP BY rco.rank_id
		HAVING COUNT(rco.rank_id) = ?
		ORDER BY ro.rank';
		my @bind_values = ($opts{id}, 1, 1);
		$returned_hash = $dbh->selectall_hashref($statement, $key_field, undef, @bind_values);
		if (scalar(keys %{$returned_hash}) < 1) { return 3 }
		
	} elsif ($opts{type} eq 'facet') {
		
		# make sure the id param was submitted
		unless ($opts{id} && $opts{id} =~ /^\d+$/) { croak "Either no id parameter was submitted or the id param value was not an integer." }
		
		# first, check to make sure that the facet exists in the database
		my $term_ids = $dbh->selectcol_arrayref('SELECT facet_id FROM facets WHERE facet_id = ?', undef, $opts{id});
		unless (scalar(@{$term_ids}) == 1) { croak "Submitted facet id not found in database or duplicate found in ranked_list()."}
		
		# then, find the ranked resources for this facet. if no resources
		# are ranked for this facet, return a special return code
		my $key_field = 'rank';
		my $statement = '
		SELECT r.resource_id, r.rank, rc.rank_id, count(rc.rank_id)
		FROM rank_criteria rc INNER JOIN rank r ON rc.rank_id = r.rank_id
		WHERE rc.facet_id = ?
		AND rc.term_id = 0 
		AND r.rank_type = \'facet\'
		GROUP BY r.rank_id
		HAVING COUNT(r.rank_id) = 1
		';
		my @bind_values = ($opts{id});
		$returned_hash = $dbh->selectall_hashref($statement, $key_field, undef, @bind_values);
		if (scalar(keys %{$returned_hash}) < 1) { return 3 }
		
	} elsif ($opts{type} eq 'combined_term') {
		
		# make sure the id param was submitted
		unless ($opts{ids}) { croak "The ids parameter was not submitted in ranked_list()." }
		unless (scalar(@{$opts{ids}}) >= 1) { croak "No term ids found in ids parameter." }
		# first, check to make sure that the terms exist in the database
		foreach my $term_id (@{$opts{ids}}) {
			my $term_ids = $dbh->selectcol_arrayref('SELECT term_id FROM terms WHERE term_id = ?', undef, $term_id);
			unless (scalar(@{$term_ids}) == 1) { return 3 }
		}
		
		# then, find the ranked resources for this term. if no resources
		# are ranked for this term, return a special return code
		my @submitted_ids = @{$opts{ids}};
		my $term_list;
		my $num_criteria = scalar(@submitted_ids);
		for (my $i = 0; $i < $num_criteria; $i++) { 
			$term_list .= $submitted_ids[$i];
			unless ($i == $num_criteria - 1) { $term_list .= ', '}; 
		}
		my $key_field = 'rank';
		my $statement = "
		SELECT ro.resource_id, ro.rank, rco.rank_id, count(rco.rank_id) 
		FROM rank_criteria rco INNER JOIN rank ro ON rco.rank_id = ro.rank_id
		WHERE rco.rank_id IN (
			SELECT r.rank_id
			FROM rank_criteria rc INNER JOIN rank r ON rc.rank_id = r.rank_id
			WHERE rc.term_id in ($term_list) 
			AND r.rank_type = \'combined_term\'
			GROUP BY r.rank_id
			HAVING COUNT(r.rank_id) = ?)
		GROUP BY rco.rank_id
		HAVING COUNT(rco.rank_id) = ?
		ORDER BY ro.rank";
		my @bind_values = ($num_criteria, $num_criteria);
		$returned_hash = $dbh->selectall_hashref($statement, $key_field, undef, @bind_values);
		if (scalar(keys %{$returned_hash}) < 1) { return 3 }
		
	}
	
	return $returned_hash;
}

=head2 rank_type() 

This is an attribute method which allows you to either get or set the rank type attribute of a rank object. Currently, a rank type must be one of three varieties: facet, single_term or combined_term. No other values will be accepted.

	# get the rank type value
	my $rank_type = $rank->rank_type();

	# set the rank type value
	$rank->rank_type(type => 'single_term');
	$rank->rank_type(type => 'combined_term');
	$rank->rank_type(type => 'facet');
	
=cut

sub rank_type {
	
	# declare local variables
	my ($self, $rank_type) = @_;

	if ($rank_type) {
		unless ($rank_type && ($rank_type eq 'single_term' || $rank_type eq 'facet' || $rank_type eq 'combined_term')) {
			croak "Either the type parameter was not submitted or an incorrect type parameter was submitted. $rank_type";
		}
		
		$self->{rank_type} = $rank_type;
	}
	
	# return the name
	return $self->{rank_type};

}

=head2 commit()

Use this method to commit the rank to the database. Any updates made to rank attributes will be saved and new ranks created will be saved. This method does not take any parameters.

	# commit the facet
	$rank->commit();

A numeric code will be returned upon successfull completion of the operation. A return code of 1 indicates a successful commit. Otherwise, the method will cease program execution and die with an appropriate error message.

There are measures in this method to rollback the commit transaction if a portion fails, but if something catastrophic happens, the application will quite with an error status and the integrity of the data may need to be checked.

An override was added for changing the rank values of existing ranks. Call the method with a single parameter "ignore_duplicate" to enable this override (with caution).

=cut

sub commit {
	
	
	# return codes for this method are:
	# 1 = success
	# 2 = duplicate rank, ignored

	my $self = shift;
	my $override_code = shift;
	my $override_cleared = 2;
	if ($override_code eq 'ignore_duplicate') {$override_cleared = 99}
	
	# check to see if basic attributes are in order
	unless ($self->rank() && $self->rank_type() && $self->resource()) { croak "One or more object attributes not set for rank in commit()." }
	
	# get a database handle
	my $dbh = MyLibrary::DB->dbh();
	
	# does the rank have any criteria assigned?
	unless ($self->{criteria}) { croak "No criteria assigned to rank. Commit failed."}
	unless (scalar(@{$self->{criteria}}) >= 1) { croak "No criteria assigned to rank. Commit failed."}
	
	my @assigned_criteria = @{$self->{criteria}};
	
	# see if the object has an id
	if ($self->{rank_id}) {
		
		# first, determine if a duplicate rank exists in the database
		my $duplicate_flag = _determine_duplicate(\@assigned_criteria, $self->rank_type(), $self->resource(), $self->rank(), $self->{rank_id});
		if ($override_cleared == 99) {$duplicate_flag = 2}
		if ($duplicate_flag == 1) { return 2; }
	
		# update the rank and criteria
		my $return = $dbh->do('UPDATE rank SET rank = ?, resource_id = ?, rank_type = ? WHERE rank_id = ?', undef, $self->rank(), $self->resource(), $self->rank_type(), $self->rank_id());
		if ($return > 1 || ! $return) { croak "Rank update in commit() failed. $return records were updated." }
		if ($self->rank_type() eq 'facet') {
			
			# remove previous criteria
			my $delete_return = $dbh->do('DELETE FROM rank_criteria WHERE rank_id = ?', undef, $self->{rank_id});
			if ($delete_return > 1 || ! $delete_return) {
				my $error = $dbh->errstr; 
				croak "Criteria update failed in commit(). Error was $error"; 
			}
			
			# insert new criteria
			my $return = $dbh->do('INSERT INTO rank_criteria (rank_id, facet_id) VALUES (?, ?)', undef, $self->{rank_id}, $assigned_criteria[0]->{facet_id});
			if ($return > 1 || ! $return) {
				# we need to roll back transaction
				 my $rv = $dbh->do('DELETE FROM rank WHERE rank_id = ?', undef, $self->{rank_id});
				croak "Criteria update failed in commit()."; 
			}
			
		} elsif ($self->rank_type() eq 'combined_term' || $self->rank_type() eq 'single_term') {
			
			# remove previous criteria
			my $delete_return = $dbh->do('DELETE FROM rank_criteria WHERE rank_id = ?', undef, $self->{rank_id});
			if ($delete_return > scalar(@assigned_criteria) || ! $delete_return) { 
				my $error = $dbh->errstr;
				croak "Criteria update failed in commit(). Data integrity may be compromised. Error was $error"; 
			}
			
			# insert new criteria
			foreach my $criteria (@assigned_criteria) {
				my $return = $dbh->do('INSERT INTO rank_criteria (rank_id, facet_id, term_id) VALUES (?, ?, ?)', undef, $self->rank_id(), $criteria->{facet_id}, $criteria->{term_id});
				if ($return > 1 || ! $return) {
					# we need to roll back the transaction
					my $delete_return = $dbh->do('DELETE FROM rank_criteria WHERE rank_id = ?', undef, $self->{rank_id});
					my $rv = $dbh->do('DELETE FROM rank WHERE rank_id = ?', undef, $self->{rank_id});
					croak "Criteria update failed in commit().";
				}
			}	
		}
	
	} else {
		
		# get a new sequence
		my $id = MyLibrary::DB->nextID();
		
		# first, determine if a duplicate rank exists in the database
		my $duplicate_flag = _determine_duplicate(\@assigned_criteria, $self->rank_type(), $self->resource(), $self->rank(), $id);
		if ($duplicate_flag == 1) { return 2; }
		
				
		# create a new rank plus criteria
		my $return = $dbh->do('INSERT INTO rank (rank_id, rank, resource_id, rank_type) VALUES (?, ?, ?, ?)', undef, $id, $self->rank(), $self->resource(), $self->rank_type());
		if ($return > 1 || ! $return) { croak 'Rank commit() failed.'; }
		$self->{rank_id} = $id;
		if ($self->rank_type() eq 'facet') {
			# insert new criteria
			my $return = $dbh->do('INSERT INTO rank_criteria (rank_id, facet_id) VALUES (?, ?)', undef, $id, $assigned_criteria[0]->{facet_id});
			if ($return > 1 || ! $return) { 
				# we need to roll back the transaction
				my $delete_return = $dbh->do('DELETE FROM rank_criteria WHERE rank_id = ?', undef, $self->{rank_id});
				my $rv = $dbh->do('DELETE FROM rank WHERE rank_id = ?', undef, $id);
				croak "Criteria creation failed in commit() for facet type ranking."; 
			}
		} elsif ($self->rank_type() eq 'combined_term' || $self->rank_type() eq 'single_term') {
			# insert new criteria
			foreach my $criteria (@assigned_criteria) {
				my $return = $dbh->do('INSERT INTO rank_criteria (rank_id, facet_id, term_id) VALUES (?, ?, ?)', undef, $self->rank_id(), $criteria->{facet_id}, $criteria->{term_id});
				if ($return > 1 || ! $return) { 
					# we need to roll back the transaction
					my $delete_return = $dbh->do('DELETE FROM rank_criteria WHERE rank_id = ?', undef, $self->{rank_id});
					my $rv = $dbh->do('DELETE FROM rank WHERE rank_id = ?', undef, $id);
					croak "Criteria creation failed in commit() for term type ranking."; 
				}
			}
		}
	}
	
	# done
	return 1;
	
}

# internal subroutine, not for public consumption
# this sub determines if there are any duplicates in the
# database which matches the criteria submitted
sub _determine_duplicate {
	
	# return values
	# 1 = duplicate
	# 2 = not duplicate
	
	my $duplicate_criteria = shift;
	my $rank_type = shift;
	my $resource_id = shift;
	my $rank_value = shift;
	my $rank_id = shift;
	my @duplicate_criteria = @{$duplicate_criteria};
	
	my $duplicate_flag = 2;
	
	my $dbh = MyLibrary::DB->dbh();
	
	if ($rank_type eq 'facet') {
		# first, make sure that the same resource isn't being given 
		# two different ranks for the same criteria
		my $facet_id = $duplicate_criteria[0]->{facet_id};
		my $statement = '
		SELECT rc.rank_id
		FROM rank_criteria rc INNER JOIN rank r ON rc.rank_id = r.rank_id
		WHERE rc.facet_id = ?
		AND rc.term_id = 0 
		AND r.rank_type = \'facet\'
		AND r.resource_id = ?
		AND r.rank_id != ?
		GROUP BY r.rank_id
		HAVING COUNT(r.rank_id) = 1
		';
		my $criteria_rows = $dbh->selectcol_arrayref($statement, undef, $facet_id, $resource_id, $rank_id);
		if (scalar(@{$criteria_rows}) >= 1) {$duplicate_flag = 1}
		# next, make sure that two resources aren't being ranked with the same rank value for
		# this criteria
		my $statement = '
		SELECT rc.rank_id
		FROM rank_criteria rc INNER JOIN rank r ON rc.rank_id = r.rank_id
		WHERE rc.facet_id = ?
		AND rc.term_id = 0 
		AND r.rank_type = \'facet\'
		AND r.rank = ?
		AND r.rank_id != ?
		GROUP BY r.rank_id
		HAVING COUNT(r.rank_id) = 1
		';
		my $criteria_rows = $dbh->selectcol_arrayref($statement, undef, $facet_id, $rank_value, $rank_id);
		if (scalar(@{$criteria_rows}) >= 1) {$duplicate_flag = 1}
		
	} elsif ($rank_type eq 'single_term' || $rank_type eq 'combined_term') {
		my $term_list;
		my $num_criteria = scalar(@duplicate_criteria);
		for (my $i = 0; $i < $num_criteria; $i++) { 
			$term_list .= $duplicate_criteria[$i]->{term_id};
			unless ($i == $num_criteria - 1) { $term_list .= ', '}; 
		}
		# first, make sure that the same resource isn't being ranked more than once with the same set of criteria
		# --the inner query finds rank ids that have at least the number of criteria required for a match
		# --the outer query makes sure that the number of criteria exactly matches the number of rank_criteria rows
		# required to match the criteria
		my $key_field = 'rank';
		my $statement = "
		SELECT ro.resource_id, ro.rank, rco.rank_id, count(rco.rank_id) 
		FROM rank_criteria rco INNER JOIN rank ro ON rco.rank_id = ro.rank_id
		WHERE rco.rank_id IN (
			SELECT r.rank_id
			FROM rank_criteria rc INNER JOIN rank r ON rc.rank_id = r.rank_id
			WHERE rc.term_id in ($term_list) 
			AND r.rank_type = ?
			AND r.resource_id = ?
			AND r.rank_id != ?
			GROUP BY r.rank_id
			HAVING COUNT(r.rank_id) = ?)
		GROUP BY rco.rank_id
		HAVING COUNT(rco.rank_id) = ?
		ORDER BY ro.rank";
		my @bind_values = ($rank_type, $resource_id, $rank_id, $num_criteria, $num_criteria, );
		my $returned_hash = $dbh->selectall_hashref($statement, $key_field, undef, @bind_values);
		if (scalar(keys %{$returned_hash}) >= 1) {$duplicate_flag = 1}
		# next, make sure that two resources aren't being ranked at the same rank level, with the same criteria
		# --for this query we switch resource_id for rank to determine the match
		my $statement = "
		SELECT ro.resource_id, ro.rank, rco.rank_id, count(rco.rank_id) 
		FROM rank_criteria rco INNER JOIN rank ro ON rco.rank_id = ro.rank_id
		WHERE rco.rank_id IN (
			SELECT r.rank_id
			FROM rank_criteria rc INNER JOIN rank r ON rc.rank_id = r.rank_id
			WHERE rc.term_id in ($term_list) 
			AND r.rank_type = ?
			AND r.rank = ?
			AND r.rank_id != ?
			GROUP BY r.rank_id
			HAVING COUNT(r.rank_id) = ?)
		GROUP BY rco.rank_id
		HAVING COUNT(rco.rank_id) = ?
		ORDER BY ro.rank";
		@bind_values = ($rank_type, $rank_value, $rank_id, $num_criteria, $num_criteria, );
		$returned_hash = $dbh->selectall_hashref($statement, $key_field, undef, @bind_values);
		if (scalar(keys %{$returned_hash}) >= 1) {$duplicate_flag = 1}
	}

	return $duplicate_flag;
}

=head2 delete()

This method will delete the ranking and any associated criteria from the database.

	# delete rank
	$rank->delete();
	
=cut

sub delete {
	
	my $self = shift;

	if ($self->rank_id()) {

		my $dbh = MyLibrary::DB->dbh();

		# delete any related rank criteria first
		my $rv = $dbh->do('DELETE FROM rank_criteria WHERE rank_id = ?', undef, $self->rank_id());
		
		# delete records from rank_data
		my $rv = $dbh->do('DELETE FROM rank_data WHERE rank_id = ?', undef, $self->rank_id());
		
		# now, delete the primary facet record
		my $rv = $dbh->do('DELETE FROM rank WHERE rank_id = ?', undef, $self->rank_id());
		if ($rv != 1) {croak ("Error deleting rank record. Deleted $rv records.");}
		 
		return 1;

	}

	return 0;

}

=head1 AUTHORS

Robert Fox <rfox2@nd.edu>

=cut

# return true, or else
1;