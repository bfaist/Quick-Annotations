
Overview
========

This simple web application is meant to provide a quick way to annotate text documents.   Real annotations systems require handling multiple annotators, possibly an arbitrator, inter-annotator agreement calculations, etc but this is not meant for that use case.

Setup
=====

1. <code>sqlite3 quick\_annotations.db < db\_setup\_quick\_annotations.sql</code>
2. Load text documents into database using your own method.
3. Modify quick\_annotations.conf as needed.  File provided is only an example.

Config File
-----------

File is in perl syntax defined in <a href="https://metacpan.org/pod/Mojolicious::Plugin::Config">Mojolicious::Plugin::Config</a>.

Config Keys Explained
--------------------- 

* dbname = filename for SQLite database
* highlight\_terms = an array of words that will be highlighted when the text document is displayed
* annotations = an array of objects used to define each annotation.  Each object will have a key for "name" and "value".

Perl Modules Required
---------------------

* Mojolicious
* DBD::SQLite

Usage
=====

1. <code>perl quick\_annotations.pl daemon</code>
2. Browse to http://localhost:3000

Export Annotations
==================

1. Browse to http://localhost:3000/export
