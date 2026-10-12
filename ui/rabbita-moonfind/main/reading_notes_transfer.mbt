///|
struct ReadingNotesImport {
  notebook : ReadingNotebook
  revision : Int
  added : Int
  skipped : Int
  detached : Int
}

///|
// The existing versioned notebook is the portable format. Compact JSON keeps
// the file and storage byte limit identical, even for nearly full notebooks.
fn reading_notes_backup(state : ReadingNotesState) -> String raise {
  guard !state.blocked else {
    fail("Saved notes must be readable before backup.")
  }
  let value = ToJson::to_json(state.notebook).stringify()
  reading_notes_decode(value, state.notebook.brief_id) |> ignore
  value
}

///|
fn reading_notes_import_preview(
  text : String,
  current : ReadingNotebook,
) -> ReadingNotesImport raise {
  let incoming = reading_notes_decode(text, current.brief_id)
  let notes = current.notes.copy()
  let existing : Map[String, ReadingNote] = Map([])
  for note in current.notes {
    existing[note.id] = note
  }
  let mut skipped = 0
  let mut detached = 0
  for note in incoming.notes {
    match existing.get(note.id) {
      Some(retained) => {
        guard retained.reference == note.reference &&
          retained.capture == note.capture &&
          retained.text == note.text else {
          fail(
            "A note ID already exists with different text or a different snapshot. Nothing was imported. Keep both backups and resolve the conflict before retrying.",
          )
        }
        // Never reattach an existing detached note from an older backup.
        skipped += 1
      }
      None => {
        let attached = note.attached && incoming.sources == current.sources
        if !attached {
          detached += 1
        }
        notes.push({ ..note, attached, })
      }
    }
  }
  let added = notes.length() - current.notes.length()
  let notebook = {
    ..current,
    revision: if added == 0 {
      current.revision
    } else {
      current.revision + 1
    },
    notes,
  }
  // Validate the entire merged result before any state or storage mutation.
  reading_notes_decode(ToJson::to_json(notebook).stringify(), current.brief_id)
  |> ignore
  { notebook, revision: current.revision, added, skipped, detached, }
}

///|
fn update_reading_notes_transfer(
  action : ReadingNotesMsg,
  state : ReadingNotesState,
) -> ReadingNotesState {
  match action {
    ExportBackup => {
      let error = reading_notes_download(reading_notes_backup(state)) catch {
        error => "\{error}"
      }
      {
        ..state,
        notice: if error.is_empty() {
          "Backup download requested for the current in-memory notes, including any unsaved edits. Check the downloaded file before clearing browser data. It includes full retained captures and private note text; review before sharing."
        } else {
          error
        },
      }
    }
    BackupLoaded(token, raw) =>
      if token != state.import_token || token.is_empty() {
        state
      } else {
        let next = { ..state, import_token: "", import_preview: None, }
        try {
          match @json.parse(raw) {
            { "cancelled": True, .. } =>
              {
                ..next,
                notice: "File selection cancelled. No notes were changed.",
              }
            { "error": String(error), .. } => { ..next, notice: error, }
            { "text": String(text), .. } =>
              update_reading_notes_transfer(ImportText(text), {
                ..next,
                notice: "Backup file loaded for preview. No notes have changed.",
              })
            _ =>
              {
                ..next,
                notice: "Could not read the backup file. No notes were changed.",
              }
          }
        } catch {
          _ =>
            {
              ..next,
              notice: "Could not read the backup file. No notes were changed.",
            }
        }
      }
    ImportText(text) =>
      if brief_text_hex(text).length() > 2 * 1024 * 1024 {
        {
          ..state,
          import_preview: None,
          import_token: "",
          notice: "Backup input exceeds 1 MiB. The previous input and notes are unchanged.",
        }
      } else {
        { ..state, import_text: text, import_token: "", import_preview: None, }
      }
    PreviewImport =>
      try {
        let preview = reading_notes_import_preview(
          state.import_text,
          state.notebook,
        )
        {
          ..state,
          import_preview: Some(preview),
          notice: "Preview only: no notes or stored bytes have changed. Confirm to merge the listed notes into this brief.",
        }
      } catch {
        error =>
          {
            ..state,
            import_preview: None,
            notice: "Backup import refused; existing notes are unchanged. \{error}",
          }
      }
    CancelImport =>
      {
        ..state,
        import_text: "",
        import_token: "",
        import_preview: None,
        notice: "Import cancelled. No notes were changed.",
      }
    ConfirmImport(text) =>
      match state.import_preview {
        Some(preview) if preview.revision == state.notebook.revision &&
          text == state.import_text => {
          let next = { ..state, import_text: "", import_preview: None, }
          if preview.added == 0 {
            {
              ..next,
              notice: "Every imported note already exists unchanged. No notes were added and stored bytes were not rewritten.",
            }
          } else {
            // Existing compare-before-write and verified-read-back semantics apply.
            // On quota/conflict failure the merged notes remain visibly unsaved.
            save_reading_notes({
              ..next,
              notebook: preview.notebook,
              saved: false,
            })
          }
        }
        _ =>
          {
            ..state,
            import_preview: None,
            notice: "Preview this backup against the current notes before confirming import.",
          }
      }
    _ => state
  }
}

///|
extern "js" fn reading_notes_download(content : String) -> String =
  #|content => {
  #| let url,link;
  #| try {
  #|  url=URL.createObjectURL(new Blob([content],{type:'application/json;charset=utf-8'}));
  #|  link=document.createElement('a'); link.href=url; link.download='moonfind-reading-notes.json';
  #|  document.body.appendChild(link); link.click(); return '';
  #| } catch (_) {return 'Reading-note backup download failed; your notes remain available. Try again.';}
  #| finally {if(link) link.remove(); if(url) setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|}

///|
// File selection only reads local bytes. Parsing/preview and the explicit merge
// stay in MoonBit. The token and revision guard reject late file callbacks.
extern "js" fn reading_notes_choose_backup(done : (String) -> Unit) -> Unit =
  #|done => {
  #| let input,finished=false;
  #| const finish=value=>{if(finished)return;finished=true;if(input)input.remove();done(JSON.stringify(value));};
  #| try {
  #|  input=document.createElement('input'); input.type='file'; input.accept='.json,application/json'; input.multiple=false;
  #|  input.addEventListener('cancel',()=>finish({cancelled:true}),{once:true});
  #|  input.addEventListener('change',async()=>{
  #|   try {
  #|    const files=Array.from(input.files||[]);
  #|    if(!files.length){finish({cancelled:true});return;}
  #|    if(files.length!==1||! /\.json$/i.test(files[0].name)||files[0].size>1048576)throw Error('Choose one JSON backup no larger than 1 MiB.');
  #|    const bytes=await files[0].arrayBuffer();
  #|    if(bytes.byteLength>1048576)throw Error('Backup exceeds 1 MiB.');
  #|    const text=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);
  #|    finish({text});
  #|   } catch(error){finish({error:'Backup file could not be read. No notes changed. '+String(error)});}
  #|  },{once:true});
  #|  input.click();
  #| } catch(error){finish({error:'Backup file chooser failed. Paste the JSON instead. '+String(error)});}
  #|}
