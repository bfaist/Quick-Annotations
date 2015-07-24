#!/usr/bin/env perl

use strict;
use Mojolicious::Lite;
use Mojo::JSON qw/encode_json decode_json/;
use DBI;

use constant ANNOTATION_STATUS_NOT_DONE => 0;
use constant ANNOTATION_STATUS_DONE => 1;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';
plugin 'Config' => { file => 'quick_annotations.conf' };

# access database handle
helper dbh => sub {
    my $c = shift;
    my $dbname = $c->config->{dbname};
    state $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
    return $dbh;
};

# find the next document if available
helper get_next_document => sub {
     my $c = shift;
     my $dbh = $c->dbh;

     my $get_next_document_sql = 'select * from annotations where annotation_status = ? limit 1';

     my $sth = $dbh->prepare_cached($get_next_document_sql);

     die "ERROR: $DBI::errstr" unless $sth;

     $sth->execute(ANNOTATION_STATUS_NOT_DONE);

     my($next_record) = $sth->fetchrow_hashref('NAME_lc');

     $sth->finish();

     return $next_record;
};

# get count of all documents
helper get_total_documents => sub {
     my $c = shift;
     my $dbh = $c->dbh;

     my $get_total_documents_sql = 'select count(*) as total_document_count from annotations';

     my $sth = $dbh->prepare_cached($get_total_documents_sql);

     die "ERROR: $DBI::errstr" unless $sth;

     $sth->execute();

     my ($total_record) = $sth->fetchrow_hashref('NAME_lc');

     $sth->finish();

     my $total_document_count = 0;

     if($total_record) {
          $total_document_count = $total_record->{total_document_count};
     }

     return $total_document_count;
};

# get count of annotated documents
helper get_annotated_count => sub {
     my $c = shift;
     my $dbh = $c->dbh;

     my $annotated_count = 0;

     my $get_annotated_count_sql = 'select count(*) as annotated_document_count from annotations where annotation_status = ?';

     my $sth = $dbh->prepare_cached($get_annotated_count_sql);

     die "ERROR: $DBI::errstr" unless $sth;

     $sth->execute(ANNOTATION_STATUS_DONE);

     my ($total_annotated) = $sth->fetchrow_hashref('NAME_lc');

     $sth->finish();

     if($total_annotated) {
         $annotated_count = $total_annotated->{annotated_document_count};
     }

     return $annotated_count;
};

# mark/highlight specific terms in document
helper format_document => sub {
     my $c = shift;
     my $document_text = shift;

     $document_text =~ s/^/<p>/;
     $document_text =~ s/$/<\/p>/;
     $document_text =~ s/[\r\n]/<\/p><p>/g;

     foreach my $highlight_term (@{ $c->config->{highlight_terms} }) {
          $document_text =~ s/($highlight_term)/<mark>$1<\/mark>/sgi;
     }

     return $document_text;
};

# store annotation from user
helper store_annotation => sub {
     my $c = shift;
     my $dbh = $c->dbh;

     my ($document_id, $annotation) = @_;

     my $update_annotation_sql = 'update annotations set annotation_status = ?, annotation = ? where document_id = ?';

     my $sth = $dbh->prepare_cached($update_annotation_sql);

     die "ERROR: $DBI::errstr" unless $sth;

     $sth->execute(ANNOTATION_STATUS_DONE, $annotation, $document_id);

     $sth->finish();
};

# retrieve all annotations and return as array ref, decode encoded JSON to perl hash
helper export_all_annotations => sub {
     my $c = shift;
     my $dbh = $c->dbh;

     my $export_all_sql = 'select * from annotations order by document_id';

     my $sth = $dbh->prepare_cached($export_all_sql);

     die "ERROR: $DBI::errstr" unless $sth;

     $sth->execute();

     my @all_records;

     while(my $record = $sth->fetchrow_hashref('NAME_lc')) {
         my $annotation = decode_json($record->{annotation});

	 $record->{annotation} = $annotation;

	 push @all_records, $record;
     }

     $sth->finish();

     return \@all_records;
};

# present annotation form to user
get '/' => sub {
  my $c = shift;
  
  my $total_document_count = $c->get_total_documents();
  my $total_annotated_document_count = $c->get_annotated_count();

  if($total_document_count == $total_annotated_document_count) {
      return $c->redirect_to('/done');
  }

  my $next_document = $c->get_next_document();
  my $next_document_html = $c->format_document($next_document->{document_text});

  $c->stash(document_text => $next_document_html);
  $c->stash(document_id => $next_document->{document_id});
  $c->stash(document_annotated_count => $total_annotated_document_count);
  $c->stash(total_document_count => $total_document_count);

  $c->render(template => 'index');
};

# tell user that all annotations are complete
get '/done' => sub {
  my $c = shift;
  $c->render(template => 'done');
};

# store annotation for this document
post '/annotate/:documentid' => sub {
   my $c = shift;

   my $document_id = $c->param('documentid');

   my %annotations;

   foreach my $annotation (@{ $c->config->{annotations} }) {
        my $annotation_value = $c->param($annotation->{name});

        $annotations{$annotation->{name}} = $annotation_value;
   }

   my $annotation_json = encode_json(\%annotations);

   $c->store_annotation($document_id, $annotation_json);

   $c->redirect_to('/')
};

# export all annotation records
get '/export' => sub {
   my $c = shift;

   my $export_records = $c->export_all_annotations();

   $c->render(json => $export_records);
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Quick Annotation';
  <div class="container">
    <h2>Quick Annotation</h2>
    <div class="pull-right bg-success"><h4>Status: <%== $document_annotated_count %> / <%== $total_document_count %></h4></div>
    <div class="panel panel-default">
      <div class="panel-body">
        <form id="annotation_form" action="/annotate/<%== $document_id %>" method="POST">
          <% foreach my $annotation (@{ $c->config->{annotations} }) { %>
          <div class="form-group">
            <label><%== $annotation->{label} %> </label>
            <% foreach my $annotation_item (@{ $annotation->{annotation_items} }) { %>
               <label><input type="radio" name="<%== $annotation->{name} %>" value="<%== $annotation_item->{value} %>"/> <%== $annotation_item->{label} %></label>
            <% } %>
          </div>
          <% } %>
          <button class="btn btn-default" type="submit">Submit</button>
        </form>
      </div>
    </div>
    <div id="document_text" class="well">
      <h4 style="line-height: 1.5">
        <%== $document_text %>
      </h4>
    </div>
  </div>

@@ done.html.ep
% layout 'default';
% title 'Quick Annotation Done';
   <div class="alert alert-success text-center">
       <h3>Annotation Complete</h3>
   </div>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css"/>
    <title><%= title %></title>
  </head>
  <body><%= content %></body>
</html>
