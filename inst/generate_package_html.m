## Copyright (C) 2008 Soren Hauberg <soren@hauberg.org>
## Copyright (C) 2014-2016 Julien Bect <jbect@users.sourceforge.net>
## Copyright (C) 2015 Oliver Heimlich <oheim@posteo.de>
## Copyright (C) 2016 Fernando Pujaico Rivera <fernando.pujaico.rivera@gmail.com>
## Copyright (C) 2017 Olaf Till <i7tiol@t-online.de>
## Copyright (C) 2022 Kai T. Ohlhus <k.ohlhus@gmail.com>
##
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 3 of the License, or (at
## your option) any later version.
##
## This program is distributed in the hope that it will be useful, but
## WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
## General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; see the file COPYING.  If not, see
## <http://www.gnu.org/licenses/>.

## -*- texinfo -*-
## @deftypefn {Function File} generate_package_html (@var{name}, @var{outdir}, @var{options})
## Generate @t{HTML} documentation for a package.
##
## The function reads information about package @var{name} using the
## package system. This is then used to generate bunch of
## @t{HTML} files; one for each function in the package, and one overview
## page. The files are all placed in the directory @var{outdir}, which defaults
## to the current directory. The @var{options} structure is used to control
## the design of the web pages.
##
## As an example, the following code generates the web pages for the @t{image}
## package:
##
## @example
## generate_package_html ("image", "out_dir");
## @end example
##
## The resulting files will be available in the @t{"out_dir"} directory. The
## index page will be called @t{"out_dir/index.html"}.
##
## If you want to include prepared package documentation in html format,
## you have to set @var{options}.package_doc manually with the filename
## of its texinfo source, which must be in the package "doc" directory.
## Contained images are automatically copied if they are at the paths
## specified in the texinfo source relative to the package "doc" directory.
## Additional arguments can be passed to makeinfo using the optional
## field @var{options}.package_doc_options.
##
## It should be noted that the function only works for installed packages.
## @seealso{get_html_options}
## @end deftypefn

function generate_package_html (packname, outdir = "htdocs", options = struct ())

  ## Check input
  if ((nargin < 1) || (nargin > 3) || ! ischar (packname))
    print_usage ();
  endif

  pkg ("load", packname);
  desc = (pkg ("describe", packname)){1};

  ## Note paths used to write html in this variable.
  paths = struct ();
  list = [];            # TODO: remove
  depends = struct ();  # TODO: remove

  if (isempty (outdir))
    outdir = packname;
  elseif (! ischar (outdir))
    error ("Second input argument must be a string");
  endif

  ## Create output directory if needed
  assert_dir (outdir);

  ## Create package directory if needed
  assert_dir (packdir = fullfile (outdir, packname));

  ## Process input argument 'options'
  if (ischar (options)) || (isstruct (options))
    options = get_html_options (options);
  else
    error ("Third input argument must be a string or a structure");
  endif

  ## Initialize setopts.
  setopts (options, desc);

  ## Function directory
  local_fundir = getopt ("function_dir");
  fundir = fullfile (packdir, local_fundir);

  ## Create function directory if needed
  assert_dir (fundir);


  ##################################################
  ## Generate html pages for individual functions ##
  ##################################################

  paths.function_help_dir = local_fundir;

  ## Since we loop over categories and functions, and now even check
  ## for both namespaces and classes already here, we use the
  ## opportunity to prepare some information for other functionality,
  ## too.

  num_categories = numel (desc.provides);

  anchors = links = implemented = first_sentences = ...
    cell (1, num_categories);

  ## hash name information, so we needn't go through all names for
  ## each letter
  name_hashes = struct ();

  for k = 1:num_categories
    printf ("Category %2d/%2d\n", k, num_categories);

    F = desc.provides{k}.functions;
    category = desc.provides{k}.category;

    ## Create a valid anchor name by keeping only alphabetical characters
    anchors{k} = regexprep (category, "[^a-zA-Z]", "_");

    ## For each function in category
    num_functions = numel (F);
    implemented{k} = false (1, num_functions);
    links{k} = first_sentences{k} = cell (1, num_functions);
    for l = 1:num_functions

      fun = F{l};
      printf ("  %2d/%2d %s\n", l, num_functions, fun);
      initial = lower (fun(isalpha (fun))(1));

      tree = {};
      ## strip and consider namespaces
      nnsp = sum (fun == ".");
      tmpfsplit = strsplit (fun, ".");
      [tree{1:nnsp}, fcn] = tmpfsplit{:};
      pkgroot = fullfile ({".."}{ones (1, 1 + nnsp)});
      assert_dir (tree, fundir);
      ## strip and consider class name
      if (fcn(1) == "@")
        tmpfsplit = strsplit (fun, "/");
        [tree{end + 1}, fcn] = tmpfsplit{:};
        pkgroot = fullfile (pkgroot, "..");
        assert_dir (fullfile (fundir, tree{:}));
      endif
      ## consider function name
      tree{end + 1} = fcn;

      subpath = fullfile (tree{1:end-1}, sprintf ("%s.html", tree{end}));
      outname = fullfile (fundir, subpath);
      if (wrote_html (outname, pkgroot, fun))
        implemented{k}(l) = true;
        links{k}{l} = fullfile (local_fundir, subpath);
        name_hashes = setfield (name_hashes, initial, tree{:},
                                [k, l]);
        first_sentences{k}{l} = try_process_first_help_sentence (fun);
      endif
    endfor

  endfor

  #########################
  ## Write overview file ##
  #########################

  paths.overview_file = "";

  if (getopt ("include_overview"))

    ## Create filename for the overview page
    overview_filename = getopt ("overview_filename");
    overview_filename = strrep (overview_filename, " ", "_");

    paths.overview_file = overview_filename;

    fid = fopen (fullfile (packdir, overview_filename), "w");
    if (fid < 0)
      error ("Couldn't open overview file for writing");
    endif

    vpars = struct ("name", packname,
                    "pkgroot", "");
    header = getopt ("overview_header", vpars);
    title  = getopt ("overview_title",  vpars);
    footer = getopt ("overview_footer", vpars);

    fprintf (fid, "%s\n", header);
    fprintf (fid, "<h1 class=\"tbdesc\">%s</h1>\n\n", desc.name);

    fprintf (fid, "<div class=\"package_description\">\n");
    fprintf (fid, "  %s\n", desc.description);
    fprintf (fid, "</div>\n\n");

    ## Generate function list by category
    for k = 1 : numel (first_sentences)
      F = desc.provides{k}.functions;
      category = desc.provides{k}.category;
      fprintf (fid, "<h2 class=\"category\">%s</h2>\n\n", category);

      ## For each function in category
      for l = 1 : numel (first_sentences{k})
        fun = F{l};
        if (! isempty (first_sentences{k}{l}))
          fprintf (fid, "<div class=\"func\"><a href=\"%s\">%s</a></div>\n",
                   links{k}{l}, fun);
          fprintf (fid, "<div class=\"ftext\">&mdash; %s</div>\n\n", ...
                   first_sentences{k}{l});
        else
          fprintf (fid, "<div class=\"func\">%s</div>\n", fun);
          fprintf (fid, "<div class=\"ftext\">No help text.</div>\n\n");
        endif
      endfor
    endfor

    fprintf (fid, "\n%s\n", footer);
    fclose (fid);
  endif

  ################################################
  ## Write function data for alphabetical lists ##
  ################################################

  paths.alphabetical_database_dir = "";

  if (getopt ("include_alpha"))

    paths.alphabetical_database_dir = "alpha";

    process_alpha_tree (name_hashes, fullfile (packdir, "alpha"),
                        first_sentences);

  endif

  #####################################################
  ## Write short description for forge overview page ##
  #####################################################

  paths.short_description_file = "";

  if (getopt ("include_package_list_item"))

    pkg_list_item_filename = getopt ("pkg_list_item_filename");

    paths.short_description_file = pkg_list_item_filename;

    vpars = struct ("name", desc.name);
    text = getopt ("package_list_item", vpars);

    fileprintf (fullfile (packdir, pkg_list_item_filename),
                pkg_list_item_filename,
                text);

  endif

  #####################
  ## Write NEWS file ##
  #####################

  paths.news_file = "";

  if (! getopt ("include_package_news"))
    write_package_news = false;
  else
    ## Read news
    filename = fullfile (list.dir, "packinfo", "NEWS");
    fid = fopen (filename, "r");
    if (fid < 0)
      warning ("generate_package_html: couldn't open NEWS for reading");
      write_package_news = false;
    else
      write_package_news = true;
      news_content = char (fread (fid).');
      fclose (fid);

      ## Open output file
      news_filename = "NEWS.html";

      paths.news_file = news_filename;

      fid = fopen (fullfile (packdir, news_filename), "w");
      if (fid < 0)
        error ("Couldn't open NEWS file for writing");
      endif

      vpars = struct ("name", desc.name,
                      "pkgroot", "");
      header = getopt ("news_header", vpars);
      title  = getopt ("news_title",  vpars);
      footer = getopt ("news_footer", vpars);

      ## Write output
      fprintf (fid, "%s\n", header);
      fprintf (fid, "<h2 class=\"tbdesc\">NEWS for '%s' Package</h2>\n\n", desc.name);
      fprintf (fid, "<p><a href=\"index.html\">Return to the '%s' package</a></p>\n\n", desc.name);

      fprintf (fid, "<pre>%s</pre>\n\n", insert_char_entities (news_content));

      fprintf (fid, "\n%s\n", footer);
      fclose (fid);
    endif
  endif

  #################################
  ## Write package documentation ##
  #################################

  # Is there a package documentation to be included ?
  write_package_documentation = ! isempty (getopt ("package_doc"));

  paths.package_doc_dir = "";

  if (write_package_documentation)

    [~, doc_fn, doc_ext] = fileparts (getopt ("package_doc"));
    doc_root_dir = fullfile (list.dir, "doc");
    doc_src = fullfile (doc_root_dir, [doc_fn, doc_ext]);
    doc_subdir = "package_doc";
    doc_out_dir = fullfile (packdir, doc_subdir);

    paths.package_doc_dir = doc_subdir;

    mkdir (doc_out_dir);

    ## Create makeinfo command
    makeinfo_cmd = sprintf ("%s --html -o %s %s", makeinfo_program (),
                            doc_out_dir, doc_src);
    if (! isempty (package_doc_options = getopt ("package_doc_options")))
      makeinfo_cmd = [makeinfo_cmd, " ", package_doc_options];
    endif

    ## Convert texinfo to HTML using makeinfo
    status = system (makeinfo_cmd);
    if (status == 127)
      error ("Program `%s' not found", makeinfo_program ());
    elseif (status)
      error ("Program `%s' returned failure code %i",
             makeinfo_program (), status);
    endif

    ## Search the name of the main HTML index file.
    package_doc_index = "index.html";
    if (! exist (fullfile (doc_out_dir, package_doc_index), "file"))
      ## Look for an HTML file with the same name as the texinfo source file
      [~, doc_fn, doc_ext] = fileparts (doc_src);
      package_doc_index = [doc_fn, ".html"];
      if (! exist (fullfile (doc_out_dir, package_doc_index), "file"))
        ## If there is only one file, no hesitation
        html_fn_list = glob (fullfile (doc_out_dir, "*.html"));
        if (length (html_fn_list) == 1)
          [~, doc_fn, doc_ext] = fileparts (html_filenames_temp{1});
          package_doc_index = [doc_fn, doc_ext];
        else
          error ("Unable to determine the root of the HTML manual.");
        endif
      endif
    endif

    ## Read image and css references from generated files and copy images
    filelist = glob (fullfile (doc_out_dir, "*.html"));
    for id = 1 : numel (filelist)
      copy_files ("image", filelist{id}, doc_root_dir, doc_out_dir);
      copy_files ("css", filelist{id}, doc_root_dir, doc_out_dir);
    endfor

  endif

  ######################
  ## Write index file ##
  ######################

  paths.index_file = "";

  if (getopt ("include_package_page"))

    ## Open output file
    index_filename = "index.html";

    paths.index_file = index_filename;

    fid = fopen (fullfile (packdir, index_filename), "w");
    if (fid < 0)
      error ("Couldn't open index file for writing");
    endif

    ## Write output
    vpars = struct ("name", desc.name,
                    "pkgroot", "");
    header = getopt ("index_header", vpars);
    title  = getopt ("index_title",  vpars);
    footer = getopt ("index_footer", vpars);

    fprintf (fid, "%s\n", header);
    fprintf (fid, "<h2 class=\"tbdesc\">%s</h2>\n\n", desc.name);

    fprintf (fid, "<table>\n");
    fprintf (fid, "<tr><td rowspan=\"2\" class=\"box_table\">\n");
    fprintf (fid, "<div class=\"package_box\">\n");
    fprintf (fid, "  <div class=\"package_box_header\"></div>\n");
    fprintf (fid, "  <div class=\"package_box_contents\">\n");
    fprintf (fid, "    <table>\n");
    fprintf (fid, "      <tr><td class=\"package_table\">Package Version:</td><td>%s</td></tr>\n",
            list.version);
    fprintf (fid, "      <tr><td class=\"package_table\">Last Release Date:</td><td>%s</td></tr>\n",
             list.date);
    fprintf (fid, "      <tr><td class=\"package_table\">Package Author:</td><td>%s</td></tr>\n",
             insert_char_entities (list.author));
    fprintf (fid, "      <tr><td class=\"package_table\">Package Maintainer:</td><td>%s</td></tr>\n",
             insert_char_entities (list.maintainer));
    fprintf (fid, "      <tr><td class=\"package_table\">License:</td><td><a href=\"COPYING.html\">");
    if (isfield (list, "license"))
      fprintf (fid, "%s</a></td></tr>\n", list.license);
    else
      fprintf (fid, "Read license</a></td></tr>\n");
    endif
    fprintf (fid, "    </table>\n");
    fprintf (fid, "  </div>\n");
    fprintf (fid, "</div>\n");
    fprintf (fid, "</td>\n\n");

    ## get icon attributions, if any
    attrib = struct ();
    attrib.download = '""';
    attrib.repository = '""';
    attrib.doc = '""';
    attrib.manual = '""';
    attrib.news = '""';
    if (! isempty (website_files = getopt ("website_files")))
      directory = fullfile (fileparts (mfilename ("fullpath")),
                            website_files, "icons");
      for [~, key] = attrib;
        attribfile = fullfile (directory,
                               sprintf ("%s.attrib", key));
        if (! isempty (stat (attribfile)))
          val = fileread (attribfile);
          val(val == "\n") = [];
          attrib.(key) = val;
        endif
      endfor
    endif
    fprintf (fid, "<td>\n");
    vpars = struct ("name", desc.name);
    if (! isempty (link = getopt ("download_link", vpars)))
      fprintf (fid, "<div class=\"download_package\">\n");
      fprintf (fid, "  <table><tr><td>\n");
      fprintf (fid, "    <a href=\"%s\" class=\"download_link\">\n", link);
      fprintf (fid, "      <img title=%s onmouseover=\"this.title=''\" src=\"../download.png\" alt=\"Package download icon\"/>\n", attrib.download);
      fprintf (fid, "    </a>\n");
      fprintf (fid, "  </td><td>\n");
      fprintf (fid, "    <a href=\"%s\" class=\"download_link\">\n", link);
      fprintf (fid, "      Download Package\n");
      fprintf (fid, "    </a></td></tr>\n");
      if (! isempty (repository_link = ...
                     getopt ("repository_link", vpars)))
        fprintf (fid, "    <tr><td>\n");
        fprintf (fid, "      <a href=\"%s\" class=\"repository_link\">\n",
                 repository_link);
        fprintf (fid,
                 "        <img title=%s onmouseover=\"this.title=''\" src=\"../repository.png\" alt=\"Repository icon\"\></a></td>\n", attrib.repository);
        fprintf (fid,
                 "  <td><a href=\"%s\" class=\"repository_link\">",
                 repository_link);
        fprintf (fid, "Repository</a>\n");
        fprintf (fid, "</td></tr>\n");
      endif
      ## The following link will have small text. So capitalize it,
      ## too, and don't put it in parantheses, otherwise it might be
      ## mistaken for a verbal attribute to the link above it.
      if (! isempty (older_versions_download = ...
                     getopt ("older_versions_download", vpars)))
        fprintf (fid, "    <tr><td /><td><a href=\"%s\"\n", older_versions_download);
        fprintf (fid, "     class=\"older_versions_download\">Older versions</a></td></tr>\n");
      end
      fprintf (fid, "  </table>\n");
      fprintf (fid, "</div>\n");
    endif
    fprintf (fid, "</td></tr>\n");
    fprintf (fid, "<tr><td>\n");
    fprintf (fid, "<div class=\"package_function_reference\">\n");
    fprintf (fid, "  <table><tr><td>\n");
    fprintf (fid, "    <a href=\"%s\" class=\"function_reference_link\">\n", overview_filename);
    fprintf (fid, "      <img title=%s onmouseover=\"this.title=''\" src=\"../doc.png\" alt=\"Function reference icon\"/>\n", attrib.doc);
    fprintf (fid, "    </a>\n");
    fprintf (fid, "  </td><td>\n");
    fprintf (fid, "    <a href=\"%s\" class=\"function_reference_link\">\n", overview_filename);
    fprintf (fid, "      Function Reference\n");
    fprintf (fid, "    </a>\n");
    fprintf (fid, "  </td></tr>\n");
    if (write_package_documentation)
      link = fullfile (doc_subdir, package_doc_index);
      fprintf (fid, "  <tr><td>\n");
      fprintf (fid, "    <a href=\"%s\" class=\"package_doc\">\n", link);
      fprintf (fid, "      <img title=%s onmouseover=\"this.title=''\" src=\"../manual.png\" alt=\"Package doc icon\"/>\n", attrib.manual);
      fprintf (fid, "    </a>\n");
      fprintf (fid, "  </td><td>\n");
      fprintf (fid, "    <a href=\"%s\" class=\"package_doc\">\n", link);
      fprintf (fid, "      Package Documentation\n");
      fprintf (fid, "    </a>\n");
      fprintf (fid, "  </td></tr>\n");
    endif
    if (write_package_news)
      fprintf (fid, "  <tr><td>\n");
      fprintf (fid, "    <a href=\"NEWS.html\" class=\"news_file\">\n");
      fprintf (fid, "      <img title=%s onmouseover=\"this.title=''\" src=\"../news.png\" alt=\"Package news icon\"/>\n", attrib.news);
      fprintf (fid, "    </a>\n");
      fprintf (fid, "  </td><td>\n");
      fprintf (fid, "    <a href=\"NEWS.html\" class=\"news_file\">\n");
      fprintf (fid, "      NEWS\n");
      fprintf (fid, "    </a>\n");
      fprintf (fid, "  </td></tr>\n");
    endif
    if (isfield (list, "url")) && (! isempty (list.url))
      index_write_homepage_links (fid, list.url);
    endif
    fprintf (fid, "  </table>\n");
    fprintf (fid, "</div>\n");
    fprintf (fid, "</td></tr>\n");
    fprintf (fid, "</table>\n\n");

    fprintf (fid, "<h3>Description</h3>\n");
    fprintf (fid, "  <div id=\"description_box\">\n")
    fprintf (fid, list.description);
    fprintf (fid, "  </div>\n\n")

    fprintf (fid, "<h3>Details</h3>\n");
    fprintf (fid, "  <table id=\"extra_package_table\">\n");

    if (isfield (list, "depends"))
      fprintf (fid, "    <tr><td>Dependencies: </td><td>\n");

      for [vt, p] = depends
        if (strcmpi (p, "octave"))
          fprintf (fid, "<a href=\"http://www.octave.org\">Octave</a> ");
        else
          fprintf (fid, "<a href=\"../%s/index.html\">%s</a> ", p, p);
        endif
        fprintf (fid, vt);
      endfor
      fprintf (fid, "</td></tr>\n");
    endif

    if (isfield (list, "systemrequirements"))
      fprintf (fid, "    <tr><td>Runtime system dependencies:</td><td>%s</td></tr>\n", list.systemrequirements);
    endif

    if (isfield (list, "buildrequires"))
      fprintf (fid, "    <tr><td>Build dependencies:</td><td>%s</td></tr>\n", list.buildrequires);
    endif

    fprintf (fid, "  </table>\n\n");

    fprintf (fid, "\n%s\n", footer);
    fclose (fid);
  endif

  ########################
  ## Write COPYING file ##
  ########################

  paths.copying_file = "";

  if (getopt ("include_package_license"))

    ## Read license
    filename = fullfile (list.dir, "packinfo", "COPYING");
    fid = fopen (filename, "r");
    if (fid < 0)
      error ("Couldn't open license for reading");
    endif
    copying_contents = char (fread (fid).');
    fclose (fid);

    ## Open output file
    copying_filename = "COPYING.html";

    paths.copying_file = copying_filename;

    fid = fopen (fullfile (packdir, copying_filename), "w");
    if (fid < 0)
      error ("Couldn't open COPYING file for writing");
    endif

    vpars = struct ("name", desc.name,
                    "pkgroot", "");
    header = getopt ("copying_header", vpars);
    title  = getopt ("copying_title",  vpars);
    footer = getopt ("copying_footer", vpars);

    ## Write output
    fprintf (fid, "%s\n", header);
    fprintf (fid, "<h2 class=\"tbdesc\">License for '%s' Package</h2>\n\n", desc.name);
    fprintf (fid, "<p><a href=\"index.html\">Return to the '%s' package</a></p>\n\n", desc.name);

    fprintf (fid, "<pre>%s</pre>\n\n", insert_char_entities (copying_contents));

    fprintf (fid, "\n%s\n", footer);
    fclose (fid);
  endif

  ########################
  ## Copy website files ##
  ########################
  if (! isempty (website_files = getopt ("website_files")))
    copyfile (fullfile (fileparts (mfilename ("fullpath")),
                        website_files, "*"),
              outdir, "f");
  endif

  ##############################################
  ## write easily parsable informational file ##
  ##############################################

  export = struct ();

  export.generator = "generate_html";

  [~, pars] = setopts ();

  export.generator_version = pars.ghv;
  export.date_generated = pars.gen_date;

  export.package.name = pars.package;

  p_fields = {"version";
              "description";
              "shortdescription"};

  for field = p_fields.'
    export.package.(field{1}) = pars.(field{1});
  endfor

  l_fields = {"date";
              "title";
              "author";
              "maintainer";
              "buildrequires";
              "systemrequirements";
              "license";
              "url"};

  for field = l_fields.'
    if (isfield (list, field{1}))
      export.package.(field{1}) = list.(field{1});
    else
      export.package.(field{1}) = "";
    endif
  endfor

  export.package.depends = depends;

  export.html.config.has_overview = getopt ("include_overview");
  export.html.config.has_alphabetical_data = getopt ("include_alpha");
  export.html.config.has_short_description = ...
    getopt ("include_package_list_item");
  export.html.config.has_news = getopt ("include_package_news");
  export.html.config.has_package_doc = ! isempty (getopt ("package_doc"));
  export.html.config.has_index = getopt ("include_package_page");
  export.html.config.has_license = getopt ("include_package_license");
  export.html.config.has_website_files = ! isempty (getopt ("website_files"));
  export.html.config.has_demos = getopt ("include_demos");

  export.html.paths = paths;

  json = encode_json_object (export);

  fileprintf (fullfile (packdir, "description.json"),
              "informational file",
              sprintf ("%s\n", json));
endfunction

function process_alpha_tree (tree, path, first_sentences)

  if (isstruct (tree))

    assert_dir (path);

    for [subtree, name] = tree

      process_alpha_tree (subtree, fullfile (path, name), first_sentences);

    endfor

  else

    fileprintf (path, "alphabet_database",
                [first_sentences{tree(1)}{tree(2)}, "\n"]);

  endif

endfunction

function copy_files (filetype, file, doc_root_dir, doc_out_dir)

  switch filetype
    case "image"
      pattern = "<(?:img.+?src|object.+?data)=""([^""]+)"".*?>";
    case "css"
      pattern = "<(?:link rel=\"stylesheet\".+?href|object.+?data)=""([^""]+)"".*?>";
    otherwise
      error ("copy_files: invalid file type");
  endswitch

  if ((fid = fopen (file)) < 0)
    error ("Couldn't open %s for reading", file);
  endif
  unwind_protect
    while (! isnumeric (l = fgetl (fid)))
      m = regexp (l, pattern, "tokens");
      for i = 1 : numel (m)
        url = m{i}{1};
        ## exclude external links
        if (isempty (strfind (url, "//")))
          if (! isempty (strfind (url, "..")))
            warning ("not copying %s %s because path contains '..'",
                     filetype, url);
          else
            if (! isempty (imgdir = fileparts (url)) &&
                ! strcmp (imgdir, "./") &&
                ! exist (imgoutdir = fullfile (doc_out_dir, imgdir), "dir"))
              [succ, msg] = mkdir (imgoutdir);
              if (!succ)
                error ("Unable to create directory %s:\n %s", imgoutdir, msg);
              endif
            endif
            if (isempty (glob (src = fullfile (doc_root_dir, url))))
              warning ("%s file %s not present, not copied",
                       filetype, url);
            elseif (! ([status, msg] = copyfile (src,
                                             fullfile (doc_out_dir, url))))
              warning ("could not copy %s file %s: %s", filetype, url, msg);
            endif
          endif
        endif
      endfor
    endwhile
  unwind_protect_cleanup
    fclose (fid);
  end_unwind_protect

endfunction

function assert_dir (directory, basepath)

  if (nargin == 2)
    ## 'directory' is a string array
    for id = 1 : numel (directory)
      assert_dir (basepath = fullfile (basepath, directory{id}));
    endfor

    return;

  endif

  ## 'directory' is a string

  if (! exist (directory, "dir"))
    [succ, msg] = mkdir (directory);
    if (! succ)
      error ("Could not create '%s': %s", directory, msg);
    endif
  endif

endfunction

function fileprintf (path, what_file, varargin)
  [fid, msg] = fopen (path, "w");
  if (fid == -1)
    error ("Could not open %s for writing", what_file);
  endif
  unwind_protect
    varargin{1} = strrep (varargin{1}, "%",    "%%");
    varargin{1} = strrep (varargin{1}, "%%%%", "%%");  # revert double escapes
    fprintf (fid, varargin{:});
  unwind_protect_cleanup
    fclose (fid);
  end_unwind_protect
endfunction

function succ = wrote_html (file, pkgroot, fun)

  try
    __html_help_text__ (file, struct ("pkgroot", pkgroot, "name", fun));
    succ = true;
  catch
    err = lasterror ();
    if (strfind (err.message, "not found"))
      warning ("marking '%s' as not implemented", fun);
      succ = false;
    else
      rethrow (err);
    endif
  end_try_catch

endfunction

function text = try_process_first_help_sentence (fun)

  try
    ## This will raise an error if the function is undocumented:
    text = get_first_help_sentence (fun, 200);
  catch
    err = lasterror ();
    if (! isempty (strfind (err.message, "not documented")))
      warning (sprintf ("%s is undocumented", fun));
      text = "Not documented";
    else
      rethrow (err);
    endif
  end_try_catch

  text = strrep (text, "\n", " ");

endfunction

function json = encode_json_object (map, indent = "")

  ## encodes only scalar structures, recursively all values must be
  ## scalar structures, strings, or booleans; adds no final newline

  if ((nf = numel (fns = fieldnames (map))))

    tmpl = strcat (["\n" indent '  "%s": %s'],
                   repmat ([",\n" indent '  "%s": %s'], 1, nf - 1));

  else
    tmpl = "";
  endif

  for id = 1:nf

    if (isstruct (map.(fns{id})))

      map.(fns{id}) = ...
      cstrcat ("\n", encode_json_object (map.(fns{id}), [indent "  "]));

    elseif (isbool (map.(fns{id})))

      if (map.(fns{id}))
        map.(fns{id}) = "true";
      else
        map.(fns{id}) = "false";
      endif

    else

      map.(fns{id}) = cstrcat ('"', map.(fns{id}), '"');

    endif

  endfor

  json = sprintf ([indent "{" tmpl "\n" indent "}"],
                  vertcat (fns.', struct2cell (map).'){:});

endfunction
