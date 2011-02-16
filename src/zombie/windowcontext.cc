#include <v8.h>
#include <node.h>

using namespace node;
using namespace v8;

class WindowContext: ObjectWrap {
private:

  // V8 Context we evaluate all code in.
  Persistent<Context> context;
  // Global scope provides access to properties and methods.
  Persistent<Object> global;

public:

  static Persistent<FunctionTemplate> s_ct;
  static void Init(Handle<Object> target) {
    Local<FunctionTemplate> t = FunctionTemplate::New(New);

    s_ct = Persistent<FunctionTemplate>::New(t);
    s_ct->InstanceTemplate()->SetInternalFieldCount(1);
    s_ct->SetClassName(String::NewSymbol("WindowContext"));

    NODE_SET_PROTOTYPE_METHOD(s_ct, "evaluate", Evaluate);
    NODE_SET_PROTOTYPE_METHOD(s_ct, "global", GetGlobal);

    target->Set(String::NewSymbol("WindowContext"), s_ct->GetFunction());
  }

  // Create a new wrapper context around the global object.
  WindowContext(Handle<Object> global) {
    Handle<ObjectTemplate> tmpl = ObjectTemplate::New();
    this->global = Persistent<Object>::New(global);
    tmpl->SetNamedPropertyHandler(GetProperty, SetProperty, NULL, DeleteProperty, EnumerateProperties, this->global);
    context = Context::New(NULL, tmpl);
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
  static Handle<Value> GetGlobal(const Arguments& args) {
    WindowContext* wc = ObjectWrap::Unwrap<WindowContext>(args.This());
    return wc->global;
  }

  // Evaluate expression or function in this context.  First argument is either
  // a function or a script (String).  In the later case, second argument
  // specifies filename.
  static Handle<Value> Evaluate(const Arguments& args) {
    WindowContext* wc = ObjectWrap::Unwrap<WindowContext>(args.This());
    Handle<Value> result;
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
    HandleScope scope;
    return scope.Close(result);
  }

  // Returns the value of a property from the global scope.
  static Handle<Value> GetProperty(Local<String> name, const AccessorInfo &info) {
    HandleScope scope;
    Local<Object> self = Local<Object>::Cast(info.Data());
    Handle<Value> result = self->Get(name);
    return scope.Close(result);
  }

  // Sets the value of a property in the global scope.
  static Handle<Value> SetProperty(Local<String> name, Local<Value> value, const AccessorInfo &info) {
    Local<Object> self = Local<Object>::Cast(info.Data());
    self->Set(name, value);
    return value;
  }

  // Deletes a property from the global scope.
  static Handle<Boolean> DeleteProperty(Local<String> name, const AccessorInfo &info) {
    Local<Object> self = Local<Object>::Cast(info.Data());
    Handle<Boolean> result = Boolean::New(self->Delete(name));
    return result;
  }

  // Enumerate all named properties in the global scope.
  static Handle<Array> EnumerateProperties(const AccessorInfo &info) {
    Local<Object> self = Local<Object>::Cast(info.Data());
    Handle<Array> names = self->GetPropertyNames();
    return names;
  }
  
};

Persistent<FunctionTemplate> WindowContext::s_ct;

extern "C" {
  static void init(Handle<Object> target) {
    WindowContext::Init(target);
  }
  NODE_MODULE(windowcontext, init);
}
