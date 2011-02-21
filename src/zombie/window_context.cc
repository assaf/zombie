#include <v8.h>
#include <node.h>

using namespace node;
using namespace v8;


// We start with an empty global scope, but we need various JavaScript
// primitives (Array, Object, encode, parseInt, etc).  We're going to create
// these primitives by running a script and assigning the result to a property
// on the global scope.
//
// There are two types of primitives: primitives we extract in the context
// (e.g. constructor for String) and primitives we extract from Zombie's global
// scope (e.g. Date object). The former has their InContext flag set to true.
//
// Since there is no String in our global scope, we need to either get it from
// another scope or create it in some other way. If we copy it from another
// scope, we get a different function, and when we later try to do something
// like this, if fails: "foo".constructor == String
//
// So instead we're going to use the current context to get the constructor for
// an empty string and assign that to the String property. We need to do this
// in the same context in which we're going to use the global scope.
//
// OTOH we have no way of obtaining a constructor for Date in that way, so we
// copy it from Zombie's global scope, and to do that we need to execute the
// script in the current context.
//
// If we're just copying a function, the script is the same as the primitive
// name and you can use the single argument constructor.
class SetPrimitive { private:
  // The script we're going to execute. Compile once for performance (this
  // really makes a difference of about 1 second in the test suite).
  Persistent<Script> script; const char *name; bool in_context;

public:
  // All powerful constructor. Specify primitive name, code we need to run to
  // extract its value, and whether or not we need to run it in context.
  //
  // If called with two arguments, we assume this script needs to be evaluated
  // in context.
  //
  // If called with one argument, we assume it's copying a property from the
  // current context, the code is the same as the primitive name and it
  // executes in the current context.
  SetPrimitive(const char *name, const char *code = NULL, bool in_context = true) {
    this->name = name;
    if (code == NULL) {
      code = name;
      in_context = false;
    }
    script = Persistent<Script>::New(Script::New(String::New(code)));
    this->in_context = in_context;
  }

  // Returns the name of this primitive (e.g. Array, escape).
  Handle<String> GetName() {
    return String::New(name);
  }

  // Returns the value of this primitive (e.g. array constructor, escape function).
  Handle<Value> GetValue() {
    return script->Run();
  }

  // Returns true if we need to run this primitive in context.
  bool InContext() {
    return in_context;
  }
  
};


// Isolated V8 Context/global scope for evaluating JavaScript, with access to
// all window methods/properties.
class WindowContext: ObjectWrap {
private:

  // V8 Context we evaluate all code in.
  Persistent<Context> context;
  // Global scope provides access to properties and methods.
  Persistent<Object> global;

public:

  static Persistent<FunctionTemplate> s_ct;
  static SetPrimitive *primitives[];


  static void Init(Handle<Object> target) {
    Local<FunctionTemplate> t = FunctionTemplate::New(New);

    s_ct = Persistent<FunctionTemplate>::New(t);
    s_ct->InstanceTemplate()->SetInternalFieldCount(1);
    s_ct->SetClassName(String::NewSymbol("WindowContext"));

    Local<ObjectTemplate> instance_t = t->InstanceTemplate();
    instance_t->SetAccessor(String::New("global"), GetGlobal);
    instance_t->SetAccessor(String::New("g"), GetG);
    NODE_SET_PROTOTYPE_METHOD(s_ct, "evaluate", Evaluate);

    target->Set(String::NewSymbol("WindowContext"), s_ct->GetFunction());
  }


  // Create a new wrapper context around the global object.
  WindowContext(Handle<Object> global) {
    Handle<ObjectTemplate> tmpl = ObjectTemplate::New();
    this->global = Persistent<Object>::New(global);
    tmpl->SetNamedPropertyHandler(GetProperty, SetProperty, QueryProperty, DeleteProperty, EnumerateProperties, this->global);
    context = Context::New(NULL, tmpl);

    // Copy primitivies in context.
    context->Enter();
    SetPrimitive *primitive;
    for (int i = 0 ; (primitive = primitives[i]) ; ++i)
      if (primitive->InContext())
        global->Set(primitive->GetName(), primitive->GetValue());
    context->Exit();
    // Copy primitivies outside context.
    for (int i = 0 ; (primitive = primitives[i]) ; ++i)
      if (!primitive->InContext())
        global->Set(primitive->GetName(), primitive->GetValue());
  }

  ~WindowContext() {
    global.Dispose();
    context.Dispose();
  }

  // Takes single argument, the global object.
  static Handle<Value> New(const Arguments& args) {
    WindowContext* wc = new WindowContext(Handle<Object>::Cast(args[0]));
    wc->Wrap(args.This());
    return args.This();
  }

  // Returns the global object.
  static Handle<Value> GetGlobal(Local<String> name, const AccessorInfo& info) {
    WindowContext* wc = ObjectWrap::Unwrap<WindowContext>(info.This());
    return wc->global;
  }

  static Handle<Value> GetG(Local<String> name, const AccessorInfo& info) {
    WindowContext* wc = ObjectWrap::Unwrap<WindowContext>(info.This());
    return wc->context->Global();
  }

  // Evaluate expression or function in this context.  First argument is either
  // a function or a script (String).  In the later case, second argument
  // specifies filename.
  static Handle<Value> Evaluate(const Arguments& args) {
    WindowContext* wc = ObjectWrap::Unwrap<WindowContext>(args.This());
    Handle<Value> result;
    TryCatch trycatch;
    wc->context->Enter();
    if (args[0]->IsFunction()) {
      // Execute function in the global scope.
      Function *fn = Function::Cast(*args[0]);
      result = fn->Call(wc->global, 0, NULL);
    } else {
      // Coerce argument into a string and execute that as a function.
      Local<String> source = args[0]->ToString();
      Local<String> filename = args[1]->ToString();
      Handle<Script> script = Script::New(source, filename);
      result = script->Run();
    }
    wc->context->Exit();
    if (result.IsEmpty())
      trycatch.ReThrow();
    return result;
  }

  // Returns the value of a property from the global scope.
  static Handle<Value> GetProperty(Local<String> name, const AccessorInfo &info) {
    Local<Object> self = Local<Object>::Cast(info.Data());
    return self->Get(name);
  }

  // Sets the value of a property in the global scope.
  static Handle<Value> SetProperty(Local<String> name, Local<Value> value, const AccessorInfo &info) {
    Local<Object> self = Local<Object>::Cast(info.Data());
    self->Set(name, Persistent<Value>::New(value));
    return value;
  }

  // Deletes a property from the global scope.
  static Handle<Boolean> DeleteProperty(Local<String> name, const AccessorInfo &info) {
    HandleScope scope;
    Local<Object> self = Local<Object>::Cast(info.Data());
    Persistent<Value> value = (Persistent<Value>) self->Get(name);
    bool deleted = self->Delete(name);
    if (deleted)
      value.Dispose();
    return scope.Close(Boolean::New(deleted));
  }

  // Enumerate all named properties in the global scope.
  static Handle<Array> EnumerateProperties(const AccessorInfo &info) {
    HandleScope scope;
    Local<Object> self = Local<Object>::Cast(info.Data());
    return scope.Close(self->GetPropertyNames());
  }

  static Handle<Integer> QueryProperty(Local<String> name, const AccessorInfo &info) {
    HandleScope scope;
    return scope.Close(Integer::New(None));
  }
  
};


Persistent<FunctionTemplate> WindowContext::s_ct;
SetPrimitive *WindowContext::primitives[] = {
  new SetPrimitive("Array", "[].constructor"),
  new SetPrimitive("Boolean", "true.constructor"),
  new SetPrimitive("Function", "(function() {}).constructor"),
  new SetPrimitive("Number", "(1).constructor"),
  new SetPrimitive("Object", "({}).constructor"),
  new SetPrimitive("RegExp", "/./.constructor"),
  new SetPrimitive("String", "''.constructor"),
  new SetPrimitive("Date"),
  new SetPrimitive("Error"),
  new SetPrimitive("Image", "{}", false),
  new SetPrimitive("Math"),
  new SetPrimitive("decodeURI"),
  new SetPrimitive("decodeURIComponent"),
  new SetPrimitive("encodeURI"),
  new SetPrimitive("encodeURIComponent"),
  new SetPrimitive("escape"),
  new SetPrimitive("eval"),
  new SetPrimitive("isFinite"),
  new SetPrimitive("isNaN"),
  new SetPrimitive("parseFloat"),
  new SetPrimitive("parseInt"),
  new SetPrimitive("unescape"),
  NULL // please don't remove
};


extern "C" {
  static void init(Handle<Object> target) {
    WindowContext::Init(target);
  }
  NODE_MODULE(window_context, init);
}
